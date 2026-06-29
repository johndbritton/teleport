//
//  TPTransfersManager.m
//  teleport
//
//  Created by JuL on 26/07/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import "TPTransfersManager.h"

#import "TPTCPSecureSocket.h"
#import "TPTransfer.h"
#import "TPMessage.h"
#import "TPLocalHost.h"
#import "TPRemoteHost.h"
#import "TPNetworkConnection.h"
#import "TPPreferencesManager.h"
#import "TPAuthenticationManager.h"

static NSString * TPTransferRequestTransferKey = @"TPTransferRequestTransfer";
static NSString * TPTransferRequestInfoDictKey = @"TPTransferRequestInfoDict";
static NSString * TPTransferRequestConnectionKey = @"TPTransferRequestConnection";

static TPTransfersManager * _transfersManager = nil;

@interface TPTransfersManager (Internal)

- (void)_processNextTransferRequestIfPossible;

@end

@implementation TPTransfersManager

+ (TPTransfersManager*)manager
{
	if(_transfersManager == nil)
		_transfersManager = [[TPTransfersManager alloc] init];
	return _transfersManager;
}

- (instancetype) init
{
	self = [super init];
	
	_outgoingTransfers = [[NSMutableDictionary alloc] init];
	_incomingTransfers = [[NSMutableDictionary alloc] init];
	_outgoingConnections = [[NSMutableDictionary alloc] init];
	_transferRequests = [[NSMutableArray alloc] init];
	_lastTransferWasCancelled = NO;
	_requestInProcess = NO;
	
	return self;
}


- (void)setDelegate:(id)delegate
{
	_delegate = delegate;
}

- (void)beginTransfer:(TPOutgoingTransfer*)transfer usingConnection:(TPNetworkConnection*)connection
{	
	BOOL transferIsOK = [transfer prepareToSendData];
	_lastTransferWasCancelled = NO;
	
	[transfer setManager:self];
	_outgoingTransfers[[transfer uid]] = transfer;
	
	if(!transferIsOK) {
		DebugLog(@"cancelled transfer %@ because there's no data", transfer);
		[self transferDidCancel:transfer];
	}
	else {
		DebugLog(@"begin transfer %@", transfer);
		
		NSDictionary * infoDict = [transfer infoDict];
		TPMessage * message = [TPMessage messageWithType:TPTransferRequestMsgType
											 andInfoDict:infoDict];
		
		_outgoingConnections[[transfer uid]] = connection; // just to retain the connection until the transfer link is established
		
		if(![connection sendMessage:message]) {
			DebugLog(@"can't send transfer request for %@", transfer);
			[self transferDidCancel:transfer];
		}
	}
}

- (void)startTransferWithUID:(NSString*)transferUID usingConnection:(TPNetworkConnection*)connection onPort:(int)port
{
	TPOutgoingTransfer * transfer = _outgoingTransfers[transferUID];

	DebugLog(@"start transfer %@", transfer);
	
	if(transfer != nil) {
		if(_delegate && [_delegate respondsToSelector:@selector(transfersManager:beginNewTransfer:)])
			[_delegate transfersManager:self beginNewTransfer:transfer];
		
		TPRemoteHost * host = [connection connectedHost];
		BOOL enableEncryption = [transfer shouldBeEncrypted] && [[TPLocalHost localHost] pairWithHost:host hasCapability:TPHostEncryptionCapability];
		TPTCPSecureSocket * socket = [[TPTCPSecureSocket alloc] initWithDelegate:transfer];
		
		[socket setEnableEncryption:enableEncryption];
		[socket setNoDelay:NO];
		[socket connectToHost:[host address] onPort:port];
		
		[transfer setSocket:socket];
	}
}

- (void)abortTransferWithUID:(NSString*)transferUID
{
	DebugLog(@"transfer with UID %@ aborted", transferUID);
	[_outgoingConnections removeObjectForKey:transferUID];
	[_outgoingTransfers removeObjectForKey:transferUID];
	[_incomingTransfers removeObjectForKey:transferUID];
}

- (void)receiveTransferRequestWithInfoDict:(NSDictionary*)infoDict onConnection:(TPNetworkConnection*)connection isClient:(BOOL)isClient
{
	NSString * transferType = infoDict[TPTransferTypeKey];
	NSString * uid = infoDict[TPTransferUIDKey];
	NSNumber * dataLengthValue = infoDict[TPTransferDataLengthKey];
	TPDataLength dataLength = [dataLengthValue longLongValue];

	DebugLog(@"receive transfer of type %@ and length %lld", transferType, dataLength);
	
	TPIncomingTransfer * transfer = [TPIncomingTransfer transferOfType:transferType withUID:uid];
	
	if(transfer != nil) {
		if(!isClient && [transfer requireTrustedHost] && ![[TPAuthenticationManager defaultManager] isHostTrusted:[connection connectedHost]]) {
			DebugLog(@"transfer requires trusted host but this one is not!");
			[connection sendMessage:[TPMessage messageWithType:TPTransferFailureMsgType
													 andString:[transfer uid]]];
		}
//		else if(_lastTransferWasCancelled) {
//			DebugLog(@"last transfer was cancelled: do not accept to receive this!");
//			
//			[connection sendMessage:[TPMessage messageWithType:TPTransferFailureMsgType
//													 andString:[transfer uid]]];
//		}
		else {
			NSDictionary * transferRequest = [[NSDictionary alloc] initWithObjectsAndKeys:
											  transfer, TPTransferRequestTransferKey,
											  infoDict, TPTransferRequestInfoDictKey,
											  connection, TPTransferRequestConnectionKey,
											  nil];
			
			[_transferRequests addObject:transferRequest];
			
			[self _processNextTransferRequestIfPossible];
		}
	}
	else
		DebugLog(@"error creating transfer of type <%@>", transferType);
}

- (void)abortAllTransferRequests
{
	NSEnumerator * transferRequestsEnum = [_transferRequests objectEnumerator];
	NSDictionary * transferRequest;
	
	while((transferRequest = [transferRequestsEnum nextObject]) != nil) {
		TPTransfer * transfer = transferRequest[TPTransferRequestTransferKey];
		[self abortTransferWithUID:[transfer uid]];
	}
	
	[_transferRequests removeAllObjects];
	_requestInProcess = NO;
}

- (void)_processNextTransferRequestIfPossible
{
	if([_transferRequests count] < 1 || _requestInProcess)
		return;

	_requestInProcess = YES;
	
	NSDictionary * transferRequest = _transferRequests[0];
	TPIncomingTransfer * transfer = transferRequest[TPTransferRequestTransferKey];
	NSDictionary * infoDict = transferRequest[TPTransferRequestInfoDictKey];
	TPNetworkConnection * connection = transferRequest[TPTransferRequestConnectionKey];
	TPRemoteHost * host = [connection connectedHost];
	int port = [[TPPreferencesManager sharedPreferencesManager] portForPref:TRANSFER_PORT];
	
	if([transfer prepareToReceiveDataWithInfoDict:infoDict fromHost:host onPort:&port delegate:[connection delegate]]) {
		if(_delegate && [_delegate respondsToSelector:@selector(transfersManager:beginNewTransfer:)])
			[_delegate transfersManager:self beginNewTransfer:transfer];
		
		[transfer setManager:self];
		_incomingTransfers[[transfer uid]] = transfer;
		
		DebugLog(@"receive transfer %@", transfer);
		
		BOOL sent = [connection sendMessage:[TPMessage messageWithType:TPTransferSuccessMsgType
														   andInfoDict:@{TPTransferUIDKey: [transfer uid],
															   TPTransferPortKey: @(port)}]];

		if(!sent) {
			NSLog(@"can't send transfer start message %@", transfer);
			_requestInProcess = NO;
			[self _processNextTransferRequestIfPossible];
		}
			
	}
	else {
		DebugLog(@"prepare failed for transfer %@", transfer);
		
		[connection sendMessage:[TPMessage messageWithType:TPTransferFailureMsgType
												 andString:[transfer uid]]];
		
		_requestInProcess = NO;
		[self _processNextTransferRequestIfPossible];
	}
}

- (void)_removeTransfer:(TPTransfer*)transfer
{
	NSString * transferUID = [transfer uid];
	[_outgoingTransfers removeObjectForKey:transferUID];
	[_incomingTransfers removeObjectForKey:transferUID];
	[_outgoingConnections removeObjectForKey:transferUID];
}

- (void)transferDidStart:(TPTransfer*)transfer
{
	DebugLog(@"transfer %@ did start", transfer);
	
	if([transfer isIncoming]) {
		if(_requestInProcess && [_transferRequests count] > 0) {
			[_transferRequests removeObjectAtIndex:0];
			_requestInProcess = NO;
			[self _processNextTransferRequestIfPossible];
		}
	}
	else {
		[_outgoingConnections removeObjectForKey:[transfer uid]];
	}
}

- (void)transfer:(TPTransfer*)transfer didProgress:(float)progress
{
	DebugLog(@"transfer %@ did progress to %f", transfer, progress);
	
	if(_delegate && [_delegate respondsToSelector:@selector(transfersManager:transfer:didProgress:)] && [transfer hasFeedback])
		[_delegate transfersManager:self transfer:transfer didProgress:progress];
}

- (void)transferDidComplete:(TPTransfer*)transfer
{
	DebugLog(@"transfer %@ did complete", transfer);
	
	if(_delegate && [_delegate respondsToSelector:@selector(transfersManager:completeTransfer:)] && [transfer hasFeedback])
		[_delegate transfersManager:self completeTransfer:transfer];
	
	[self _removeTransfer:transfer];
}

- (void)transferDidCancel:(TPTransfer*)transfer
{
	DebugLog(@"transfer %@ did cancel", transfer);
	
	if(_delegate && [_delegate respondsToSelector:@selector(transfersManager:cancelTransfer:)] && [transfer hasFeedback])
		[_delegate transfersManager:self cancelTransfer:transfer];
	
	[self _removeTransfer:transfer];
	
	_lastTransferWasCancelled = YES;
}

@end
