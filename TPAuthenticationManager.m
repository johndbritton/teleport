//
//  TPAuthenticationManager.m
//  teleport
//
//  Created by JuL on Thu Mar 04 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPAuthenticationManager.h"
#import "TPPreferencesManager.h"
#import "TPHostsManager.h"
#import "TPAuthenticationRequest.h"
#import "TPMainController.h"
#import "TPLocalHost.h"
#import "TPRemoteHost.h"
#import "TPConnectionsManager.h"
#import "TPTransfersManager.h"
#import "TPBackgroundImageTransfer.h"
#import "TPTCPSecureSocket.h"
#import "TPMessage.h"

#define TRUSTED_HOSTS_VERSION 2

NSString * TPTrustedHostsVersionKey = @"TPTrustedHostsVersion";
NSString * TPTrustedHostsKey = @"TPTrustedHosts";

static TPAuthenticationManager * _defaultManager = nil;

static BOOL TPCertificateEqual(SecCertificateRef cert1Ref, SecCertificateRef cert2Ref)
{
	CSSM_DATA certData1, certData2;
	
	SecCertificateGetData(cert1Ref, &certData1);
	SecCertificateGetData(cert2Ref, &certData2);
	
	if(certData1.Length != certData2.Length)
		return NO;
	
	if(memcmp(certData1.Data, certData2.Data, certData1.Length) == 0)
		return YES;
	else
		return NO;
}


@implementation TPAuthenticationManager

+ (TPAuthenticationManager*)defaultManager
{
	if(_defaultManager == nil)
		_defaultManager = [[TPAuthenticationManager alloc] init];
	return _defaultManager;
}

- (instancetype)init
{
	self = [super init];

	_trustedHosts = [[NSMutableArray alloc] init];

	return self;
}



#pragma mark -
#pragma mark Loading/Saving

- (void)loadHosts
{
	if([[TPPreferencesManager sharedPreferencesManager] intForPref:TPTrustedHostsVersionKey] != TRUSTED_HOSTS_VERSION) // do not load hosts from an earlier version
		return;
	
	NSData * archivedData = [[TPPreferencesManager sharedPreferencesManager] valueForPref:TPTrustedHostsKey];
	if(archivedData == nil)
		return;
	
	NSArray * trustedHosts = nil;
	
	@try {
		trustedHosts = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
	}
	@catch(NSException * e) {
		trustedHosts = nil;
	}
	
	if(trustedHosts != nil)
		[_trustedHosts addObjectsFromArray:trustedHosts];
}

- (void)saveHosts
{
	NSData * archivedData = [NSKeyedArchiver archivedDataWithRootObject:_trustedHosts];
	[[TPPreferencesManager sharedPreferencesManager] setValue:archivedData forKey:TPTrustedHostsKey];
	[[TPPreferencesManager sharedPreferencesManager] setValue:@TRUSTED_HOSTS_VERSION forKey:TPTrustedHostsVersionKey];
}


#pragma mark -
#pragma mark Authentication requests - client side

- (BOOL)requestAuthenticationOnHost:(TPRemoteHost*)host
{
	return [[TPConnectionsManager manager] connectToHost:host withDelegate:self infoDict:nil];
}

- (void)connectionToServerSucceeded:(TPNetworkConnection*)connection infoDict:(NSDictionary*)infoDict
{
	_currentConnection = connection;
	[_currentConnection setDelegate:self];
	[_currentConnection sendMessage:[TPMessage messageWithType:TPAuthenticationRequestMsgType]];
}

- (void)connectionToServerFailed:(TPRemoteHost*)host infoDict:(NSDictionary*)infoDict
{
	[host setHostState:TPHostSharedState];
	
	NSString * msgTitle = [NSString stringWithFormat:NSLocalizedString(@"Connection to \\U201C%@\\U201D failed.", @"Title for connection failure"), [host computerName]];
	NSAlert * alert = [NSAlert alertWithMessageText:msgTitle defaultButton:NSLocalizedString(@"OK", nil) alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"The server may be down, or an encryption problem may have occured. If encryption is enabled, please check that the certificate algorithms match.", nil)];
	[(TPMainController*)[NSApp delegate] performSelector:@selector(presentAlert:) withObject:alert afterDelay:0];
}

- (void)connection:(TPNetworkConnection*)connection receivedMessage:(TPMessage*)message
{
	TPMsgType type = [message msgType];
	TPRemoteHost * host = [connection connectedHost];
	
#if DEBUG_GENERAL
	DebugLog(@"authentication manager receive msg %ld", type);
#endif
	switch(type) {
		case TPAuthenticationInProgressMsgType:
		{
			break;
		}
		case TPAuthenticationSuccessMsgType:
		{
			[host setHostState:TPHostPeeredOnlineState];
			_currentConnection = nil;
			break;
		}
		case TPAuthenticationFailureMsgType:
		{
			NSString * msgTitle = [NSString stringWithFormat:NSLocalizedString(@"The host \\U201C%@\\U201D rejected your trust request.", @"Title for trust failure"), [host computerName]];
			NSString * explanation = [message infoDict][@"reason"];
			if(explanation == nil)
				explanation = NSLocalizedString(@"The computer you tried to control rejected your request. You should try on a computer you own.", nil);
			
	
			[host setHostState:TPHostSharedState];

			NSAlert * alert = [NSAlert alertWithMessageText:msgTitle defaultButton:NSLocalizedString(@"OK", nil) alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", explanation];
			[(TPMainController*)[NSApp delegate] presentAlert:alert];
			
			_currentConnection = nil;
			break;
		}
		case TPTransferRequestMsgType:
			[[TPTransfersManager manager] receiveTransferRequestWithInfoDict:[message infoDict] onConnection:connection isClient:NO];
			break;
		case TPTransferSuccessMsgType:
			[[TPTransfersManager manager] startTransferWithUID:[message infoDict][TPTransferUIDKey] usingConnection:connection onPort:[[message infoDict][TPTransferPortKey] intValue]];
			break;
		case TPTransferFailureMsgType:
			[[TPTransfersManager manager] abortTransferWithUID:[message string]];
			break;
		default:
			NSLog(@"invalid msg: %ld", type);
	}
}

- (void)abortAuthenticationRequest
{
	if(_currentConnection != nil)
		[_currentConnection sendMessage:[TPMessage messageWithType:TPAuthenticationAbortMsgType]];
}


#pragma mark -
#pragma mark Authentication requests - server side

- (void)authenticationRequestedFromHost:(TPRemoteHost*)host onConnection:(TPNetworkConnection*)connection
{
	if([self isHostTrusted:host]) {
		if([[TPLocalHost localHost] hasCustomBackgroundImage])
			[[TPTransfersManager manager] beginTransfer:[TPOutgoingBackgroundImageTransfer transfer] usingConnection:connection];
		[connection sendMessage:[TPMessage messageWithType:TPAuthenticationSuccessMsgType]];
	}
	else {
		if([[TPPreferencesManager sharedPreferencesManager] boolForPref:TRUST_LOCAL_CERTIFICATE]) {
			SecCertificateRef remoteHostCertRef = [host certificate];
			if(remoteHostCertRef != NULL) {
				SecIdentityRef identityRef = [[TPLocalHost localHost] identity];
				SecCertificateRef localHostCertRef = NULL;
				if(SecIdentityCopyCertificate(identityRef, &localHostCertRef) == noErr) {
					if(localHostCertRef != NULL) {
						if(TPCertificateEqual(remoteHostCertRef, localHostCertRef)) {
							[self host:host setTrusted:YES];
							if([[TPLocalHost localHost] hasCustomBackgroundImage])
								[[TPTransfersManager manager] beginTransfer:[TPOutgoingBackgroundImageTransfer transfer] usingConnection:connection];
							[connection sendMessage:[TPMessage messageWithType:TPAuthenticationSuccessMsgType]];
							return;
						}
						CFRelease(localHostCertRef);
					}
				}
			}
		}
		
		int trustRequestBehavior = [[TPPreferencesManager sharedPreferencesManager] intForPref:TRUST_REQUEST_BEHAVIOR];
		
		switch(trustRequestBehavior) {
			case TRUST_REQUEST_REJECT:
				[connection sendMessage:[TPMessage messageWithType:TPAuthenticationFailureMsgType
													   andInfoDict:@{@"reason": NSLocalizedString(@"Host not accepting any more trusted hosts.", @"Reason for trust failure")}]];
				DebugLog(@"Rejecting authentication: no more authentication");
				break;
				
			case TRUST_REQUEST_ACCEPT:
				[self host:host setTrusted:YES];
				if([[TPLocalHost localHost] hasCustomBackgroundImage])
					[[TPTransfersManager manager] beginTransfer:[TPOutgoingBackgroundImageTransfer transfer] usingConnection:connection];
				[connection sendMessage:[TPMessage messageWithType:TPAuthenticationSuccessMsgType]];
				break;
				
			case TRUST_REQUEST_ASK:
			default:
			{
				[connection sendMessage:[TPMessage messageWithType:TPAuthenticationInProgressMsgType]];
				
				TPAuthenticationRequest * authenticationRequest = [[TPAuthenticationRequest alloc] initWithNetworkConnection:connection demandingHost:host];
				
				TPAuthenticationResult result = [authenticationRequest ask];
				[self replyToAuthenticationRequest:authenticationRequest withResult:result];
				
				[connection setDelegate:self];
				break;
			}
		}
	}
}

- (void)replyToAuthenticationRequest:(TPAuthenticationRequest*)authRequest withResult:(TPAuthenticationResult)result
{
	switch(result) {
		case TPAuthenticationAcceptedAndRejectOthersResult:
			[[TPPreferencesManager sharedPreferencesManager] setValue:@(TRUST_REQUEST_REJECT) forKey:TRUST_REQUEST_BEHAVIOR];
			// no break
		case TPAuthenticationAcceptedResult:
		{
			TPRemoteHost * host = [authRequest demandingHost];
			DebugLog(@"authentication request from host %@ accepted", host);
			
			[self host:host setTrusted:YES];

			TPNetworkConnection * connection = [authRequest connection];
			if([[TPLocalHost localHost] hasCustomBackgroundImage])
				[[TPTransfersManager manager] beginTransfer:[TPOutgoingBackgroundImageTransfer transfer] usingConnection:connection];
			[connection sendMessage:[TPMessage messageWithType:TPAuthenticationSuccessMsgType]];
			break;
		}
		case TPAuthenticationRejectedResult:
			[[authRequest connection] sendMessage:[TPMessage messageWithType:TPAuthenticationFailureMsgType
												   andInfoDict:@{@"reason": NSLocalizedString(@"User rejected your trust request.", @"Reason for trust failure")}]];
			DebugLog(@"Rejecting authentication: user decision");
			break;
		case TPAuthenticationAbortedResult:
			DebugLog(@"Authentication aborted");
	}
}


#pragma mark -
#pragma mark Trusted hosts

- (NSArray*)trustedHosts
{
	return _trustedHosts;
}

- (void)host:(TPRemoteHost*)remoteHost setTrusted:(BOOL)trusted
{
	[_trustedHosts removeObject:remoteHost];
	
	if(trusted)
		[_trustedHosts addObject:remoteHost];
	
	[self saveHosts];
}

- (BOOL)isHostTrusted:(TPRemoteHost*)remoteHost
{
	BOOL trusted = NO;
#if LEGACY_BUILD
	unsigned index;
#else
	NSUInteger index;
#endif
	index = [_trustedHosts indexOfObject:remoteHost];
	if(index != NSNotFound) {
		TPRemoteHost * trustedRemoteHost = _trustedHosts[index];
		SecCertificateRef trustedCertRef = [trustedRemoteHost certificate];
		if(trustedCertRef == NULL) {
			trusted = YES; // trusting a non certified host
		}
		else {
			SecCertificateRef certRef = [remoteHost certificate];
			if(certRef != NULL) {
				trusted =  TPCertificateEqual(trustedCertRef, certRef);
			}
		}
	}

	if(trusted)
		[self host:remoteHost setTrusted:YES];
	
	return trusted;
}

@end
