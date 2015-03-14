//
//  TPTransfer.m
//  teleport
//
//  Created by JuL on 13/02/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import "TPTransfer.h"
#import "TPTransfer_Private.h"

#import "TPConnectionsManager.h"
#import "TPPreferencesManager.h"
#import "TPTCPSecureSocket.h"

#import "TPLocalHost.h"
#import "TPRemoteHost.h"

#include <unistd.h>

#define REFRESH_RATE 0.1
#define BLOCK_SIZE 256*1024
#define SLEEP_LENGTH 20000

NSString * TPTransferUIDKey = @"TPTransferUID";
NSString * TPTransferTypeKey = @"TPTransferType";
NSString * TPTransferDataLengthKey = @"TPTransferDataLength";
NSString * TPTransferPortKey = @"TPTransferPort";
NSString * TPTransferShouldEncryptKey = @"TPTransferShouldEncrypt";

@interface TPTransfer (Internal)

@property (nonatomic, readonly) BOOL _listen;

- (void)_beginTransfer;

- (void)_receivedData:(NSData*)data;

@end

@implementation TPTransfer

- (instancetype) init
{
	self = [super init];
	
	_data = nil;
	_manager = nil;
	_socket = nil;
	_listenSocket = nil;
	_lock = [[NSLock alloc] init];
	
	return self;
}

- (void)dealloc
{
	[_socket setDelegate:nil];
}


#pragma mark -
#pragma mark Attributes

- (NSString*)type
{
	return @"TPIncomingTransfer";
}

- (NSString*)uid
{
	return _uid;
}

- (TPTransferPriority)priority
{
	return TPTransferLowPriority;
}

//- (void)setDelegate:(id)delegate
//{
//	_delegate = delegate;
//}
//
//- (id)delegate
//{
//	return _delegate;
//}

- (void)setManager:(TPTransfersManager*)manager
{
	_manager = manager;
}

- (BOOL)isIncoming
{
	return NO;
}

- (BOOL)hasFeedback
{
	return NO;
}

- (NSString*)completionMessage
{
	return nil;
}

- (NSString*)errorMessage
{
	return nil;
}


#pragma mark -
#pragma mark Status

- (void)_beginTransfer
{
}

- (void)_notifyProgress:(NSNumber*)transferedNumber
{
	TPDataLength transferedDataLength = [transferedNumber unsignedLongLongValue];
	float progress = (double)transferedDataLength/(double)_totalDataLength;
	[_manager transfer:self didProgress:progress];
}

- (void)_transferDone
{
	DebugLog(@"tranfer %@ done", self);
	
	[_lock lock];
	
	[_socket setDelegate:nil];
	[_socket close];
	_socket = nil;
	
	_data = nil;
	
	[_lock unlock];
}

- (void)_receivedData:(NSData*)data
{
	DebugLog(@"%@ _receivedData %@", self, data);

}


#pragma mark -
#pragma mark TCP Socket delegate

- (void)tcpSocket:(TPTCPSecureSocket*)listenSocket secureConnectionAccepted:(TPTCPSecureSocket*)childSocket
{
	[self tcpSocket:listenSocket connectionAccepted:childSocket];
}

- (void)tcpSocketSecureConnectionSucceeded:(TPTCPSecureSocket*)tcpSocket
{
	[self tcpSocketConnectionSucceeded:tcpSocket];
}

- (void)tcpSocketSecureConnectionFailed:(TPTCPSecureSocket*)tcpSocket
{
	[self tcpSocketConnectionFailed:tcpSocket];
}

- (void)tcpSocket:(TPTCPSocket*)tcpSocket gotData:(NSData*)data
{
#if DEBUG_TRANSFERS
	DebugLog(@"transfer socket %@ got data (length %d)", tcpSocket, (int)[data length]);
#endif
	
	[self _receivedData:data];
}

- (void)tcpSocketDidSendData:(TPTCPSocket*)tcpSocket
{
#if DEBUG_TRANSFERS
	DebugLog(@"transfer socket %@ did send data on thread %p", tcpSocket, [NSThread currentThread]);
#endif
}

- (void)tcpSocketConnectionClosed:(TPTCPSocket*)tcpSocket
{
#if DEBUG_TRANSFERS
	DebugLog(@"transfer socket %@ connection closed", tcpSocket);
#endif
}

- (SecIdentityRef)tcpSecureSocketCopyIdentity:(TPTCPSecureSocket*)tcpSocket
{
	return [[TPConnectionsManager manager] tcpSecureSocketCopyIdentity:tcpSocket];
}

- (BOOL)tcpSecureSocketShouldEnableEncryption:(TPTCPSecureSocket*)tcpSocket
{
	return NO;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@<%p> uid:%@", [self class], self, [self uid]];
}

@end

@implementation TPOutgoingTransfer

+ (TPOutgoingTransfer*)transfer
{
	TPOutgoingTransfer * transfer = [[self alloc] init];
	transfer->_uid = [[[NSProcessInfo processInfo] globallyUniqueString] copy];
	return transfer;
}

- (BOOL)shouldBeEncrypted
{
	return NO;
}

- (BOOL)prepareToSendData
{
#if DEBUG_TRANSFERS
	DebugLog(@"prepareToSendData");
#endif
	
	NSData * dataToTransfer = [self dataToTransfer];
	if(dataToTransfer == nil)
		return NO;
	
	
	_data = [dataToTransfer mutableCopy];
	_totalDataLength = [_data length];
	
	return YES;
}

- (void)_beginTransfer
{
	if(_totalDataLength > 0) {
		[_socket _setRunLoop:NULL];	
		[NSThread detachNewThreadSelector:@selector(_sendDataThread) toTarget:self withObject:nil];
	}
}

- (void)_sendDataThread
{
	@autoreleasepool {
		SInt32 ret = kCFRunLoopRunTimedOut;
		[_socket _setRunLoop:CFRunLoopGetCurrent()];
		
		if(_totalDataLength > 0) {
			NSDate * lastDate = [[NSDate alloc] init];
			NSRange sendRange = NSMakeRange(0, MIN(BLOCK_SIZE, _totalDataLength));
			
			while(_data != nil && sendRange.length > 0) {
				if(-[lastDate timeIntervalSinceNow] >= REFRESH_RATE) {
					[self performSelectorOnMainThread:@selector(_notifyProgress:) withObject:[NSNumber numberWithUnsignedLongLong:sendRange.location] waitUntilDone:NO];
					lastDate = [[NSDate alloc] init];
				}
				
#if DEBUG_TRANSFERS
				DebugLog(@"send data of length %d on thread %p", (int)sendRange.length, [NSThread currentThread]);
#endif
				
				[_lock lock];
				NSData * sendData = [_data subdataWithRange:sendRange];
				BOOL sent = [_socket sendData:sendData];
				[_lock unlock];
				
				if(!sent) {
					break;
				}
				else {
					sendRange.location += sendRange.length;
					sendRange.length = MIN(BLOCK_SIZE, _totalDataLength - sendRange.location);
				}
			}
			
			
			if(sendRange.location == _totalDataLength)
				[self performSelectorOnMainThread:@selector(_senderDataTransferCompleted) withObject:nil waitUntilDone:YES];
			else
				[self performSelectorOnMainThread:@selector(_senderDataTransferAborted) withObject:nil waitUntilDone:YES];		
		}
		else {
			while(_data != (id)[NSNull null]) {
				if(_data != nil) {
					[_lock lock];
					BOOL sent = [_socket sendData:_data];
					_data = nil;
					[_lock unlock];
					
					ret = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.0, false);
					
					if(!sent) {
						break;
					}				
				}
			}
			
			if(_data == (id)[NSNull null])
				[self performSelectorOnMainThread:@selector(_senderDataTransferCompleted) withObject:nil waitUntilDone:YES];
			else
				[self performSelectorOnMainThread:@selector(_senderDataTransferAborted) withObject:nil waitUntilDone:YES];		
			
		}
		
	}
}

- (void)_senderDataTransferCompleted
{
	[self _transferDone];
	[_manager transferDidComplete:self];
}

- (void)_senderDataTransferFailed
{
	[self _transferDone];
	[_manager transferDidCancel:self];
}

- (void)_senderDataTransferAborted
{
	[self _transferDone];
	[_manager transferDidCancel:self];
}

- (void)setSocket:(TPTCPSocket*)socket
{
	_socket = (TPTCPSecureSocket*)socket;
	[_socket setDelegate:self];
}

- (NSData*)dataToTransfer
{
	return [NSData data];
}

- (TPDataLength)totalDataLength
{
	return _totalDataLength;
}

- (NSDictionary*)infoDict
{
	return @{TPTransferUIDKey: [self uid],
			TPTransferTypeKey: [self type],
			TPTransferDataLengthKey: @([self totalDataLength]),
			TPTransferShouldEncryptKey: @([self shouldBeEncrypted])};
}


#pragma mark -
#pragma mark Socket delegate

- (BOOL)tcpSecureSocketShouldEnableEncryption:(TPTCPSecureSocket*)tcpSocket
{
	return [self shouldBeEncrypted] && [[TPConnectionsManager manager] tcpSecureSocketShouldEnableEncryption:tcpSocket];
}

- (void)tcpSocketConnectionSucceeded:(TPTCPSocket*)tcpSocket
{
	DebugLog(@"transfer %@ socket %@ succeeded to %@", self, tcpSocket, [_socket remoteAddress]);
		
	[_manager transferDidStart:self];
	[self _beginTransfer];
}

- (void)tcpSocketConnectionFailed:(TPTCPSocket*)tcpSocket
{
	DebugLog(@"transfer %@ socket %@ connection failed", self, tcpSocket);
	
	[self _senderDataTransferFailed];
}

@end

#pragma mark -

@implementation TPIncomingTransfer

+ (TPIncomingTransfer*)transferOfType:(NSString*)type withUID:(NSString*)uid
{
	Class transferClass = NSClassFromString(type);
	if(transferClass == Nil) {
		return nil;
	}
	
	TPIncomingTransfer * transfer = [[transferClass alloc] init];
	transfer->_uid = uid;
	return transfer;
}

- (void)dealloc
{
	[self _stopListening];
}

- (BOOL)_listenOnPort:(int*)port forHost:(TPRemoteHost*)host encrypt:(BOOL)shouldEncrypt
{
	if(_listenSocket == nil) {
		_listenSocket = [[TPTCPSecureSocket alloc] initWithDelegate:self];
		
		BOOL enableEncryption = shouldEncrypt && [[TPLocalHost localHost] pairWithHost:host hasCapability:TPHostEncryptionCapability];
		[_listenSocket setEnableEncryption:enableEncryption];
		
		return [_listenSocket listenOnPort:port tries:50];
	}
	else
		return YES;
}

- (void)_stopListening
{
	if(_listenSocket != nil) {
		[_listenSocket setDelegate:nil];
		[_listenSocket close];
		_listenSocket = nil;
	}
}

- (BOOL)isIncoming
{
	return YES;
}

- (BOOL)requireTrustedHost
{
	return NO;
}

- (BOOL)prepareToReceiveDataWithInfoDict:(NSDictionary*)infoDict fromHost:(TPRemoteHost*)host onPort:(int*)port delegate:(id)delegate
{
#if DEBUG_TRANSFERS
	DebugLog(@"prepareToReceiveData");
#endif
	
	_totalDataLength = [infoDict[TPTransferDataLengthKey] longLongValue];
	_shouldEncrypt = [infoDict[TPTransferShouldEncryptKey] boolValue];
	
	/* Setup buffer for data transfer */
	if(_totalDataLength > 0) {
		_data = [[NSMutableData alloc] initWithCapacity:_totalDataLength];
		[_data setLength:_totalDataLength];
	}
	
	/* Listen to sender */
	return [self _listenOnPort:port forHost:host encrypt:_shouldEncrypt];
}

- (void)_beginTransfer
{
		[_socket _setRunLoop:NULL]; // prevents it from receiving stuff while the thread starts

	//if(_totalDataLength > 0) {
		[NSThread detachNewThreadSelector:@selector(_receiveDataThread) toTarget:self withObject:nil];
	//}
}

- (void)_notifyProgress:(NSNumber*)transferedNumber
{
	[super _notifyProgress:transferedNumber];
	
	TPDataLength transferedDataLength = [transferedNumber unsignedLongLongValue];
	float progress = (double)transferedDataLength/(double)_totalDataLength;
	[self _transferDidProgress:progress];
}

- (void)_transferDidProgress:(float)progress
{
}

- (void)_receivedData:(NSData*)data
{
#if DEBUG_TRANSFERS
	DebugLog(@"tranfer %@ receivedData (%d) in thread %@", self, (int)[data length], [NSThread currentThread]);
#endif
	
	unsigned dataLength = [data length];
	[_lock lock];
	[_data replaceBytesInRange:NSMakeRange(_receivedDataLength, dataLength) withBytes:[data bytes] length:dataLength];
	[_lock unlock];
	_receivedDataLength += dataLength;
}

- (void)_receiveDataThread
{
	@autoreleasepool {
		SInt32 ret = kCFRunLoopRunTimedOut;

		[_socket _setRunLoop:CFRunLoopGetCurrent()];
		
		if(_totalDataLength > 0) {
			_receivedDataLength = 0;
			
			while(ret != kCFRunLoopRunFinished && _data != nil && _receivedDataLength < _totalDataLength) {
				@autoreleasepool {
				
				//		DebugLog(@"running runloop %@ in mode %@", CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
					ret = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.0, false);
					
					NSDate * lastDate = [[NSDate alloc] init];
					if(-[lastDate timeIntervalSinceNow] >= REFRESH_RATE) {
						[self performSelectorOnMainThread:@selector(_notifyProgress:) withObject:@(_receivedDataLength) waitUntilDone:NO];
						lastDate = [[NSDate alloc] init];
					}
				}
			}
			
			[_socket _setRunLoop:NULL];
			
			if(_receivedDataLength == _totalDataLength)
				[self performSelectorOnMainThread:@selector(_receiverDataTransferCompleted) withObject:nil waitUntilDone:YES];
			else
				[self performSelectorOnMainThread:@selector(_receiverDataTransferAborted) withObject:nil waitUntilDone:YES];		
		}
		else {
			while(ret != kCFRunLoopRunFinished && _totalDataLength != -1) {
				@autoreleasepool {
							
					ret = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.0, false);
				//NSLog(@"run");
				}
			}
			
			[_socket _setRunLoop:NULL];
			
			[self performSelectorOnMainThread:@selector(_receiverDataTransferCompleted) withObject:nil waitUntilDone:YES];

		}
		
	}
}

- (void)_receiverDataTransferCompleted
{
	[self _transferDone];
	[_manager transferDidComplete:self];
}

- (void)_receiverDataTransferFailed
{
	[self _transferDone];
	[_manager transferDidCancel:self];
}

- (void)_receiverDataTransferAborted
{
	[self _transferDone];
	[_manager transferDidCancel:self];
}


#pragma mark -
#pragma mark Socket delegate

- (BOOL)tcpSecureSocketShouldEnableEncryption:(TPTCPSecureSocket*)tcpSocket
{
	return _shouldEncrypt && [[TPConnectionsManager manager] tcpSecureSocketShouldEnableEncryption:tcpSocket];
}

- (void)tcpSocket:(TPTCPSocket*)listenSocket connectionAccepted:(TPTCPSocket*)childSocket
{
	DebugLog(@"transfer %@ socket accepted from %@ on %@", self, listenSocket, childSocket);
	
	if(_socket != nil) {
		[_socket close];
	}
	_socket = (TPTCPSecureSocket*)childSocket;
	[_socket setNoDelay:NO];
	[_socket setDelegate:self];
	
	[self _stopListening];
	
	[_manager transferDidStart:self];
	
	[self _beginTransfer];
}

- (void)tcpSocketConnectionFailed:(TPTCPSocket*)tcpSocket
{
	DebugLog(@"transfer %@ socket %@ connection failed", self, tcpSocket);
	
	[self _receiverDataTransferFailed];
}

- (void)tcpSocketConnectionClosed:(TPTCPSocket*)tcpSocket
{
	if(_totalDataLength == 0) {
	_totalDataLength = -1;
//		[self _receiverDataTransferCompleted];
	}
}

@end
