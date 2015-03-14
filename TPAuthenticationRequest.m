//
//  TPAuthenticationRequest.m
//  teleport
//
//  Created by JuL on 28/02/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import "TPAuthenticationRequest.h"

#import "TPMessage.h"
#import "TPLocalHost.h"
#import "TPRemoteHost.h"
#import "TPNetworkConnection.h"
#import "TPMainController.h"

@implementation TPAuthenticationRequest

- (instancetype) initWithNetworkConnection:(TPNetworkConnection*)connection demandingHost:(TPRemoteHost*)demandingHost
{
	self = [super init];
	
	_connection = connection;
	_demandingHost = demandingHost;
	
	[_connection setDelegate:self];
	
	return self;
}


- (TPAuthenticationResult)ask
{
	NSString * msgString;
	NSString * textString;
	
	if([[TPLocalHost localHost] pairWithHost:_demandingHost hasCapability:TPHostEncryptionCapability]) {
		msgString = [NSString stringWithFormat:NSLocalizedString(@"Trust request from certified host \\U201C%@\\U201D.", @"teleport trust request title - certified version"), [_demandingHost computerName]];
		textString = NSLocalizedString(@"This will allow the demanding host to take control of your mouse and keyword. All keystrokes and transfers will be encrypted with this host.\nIf you didn't request the control, you should Reject it.", nil);
	}
	else {
		msgString = [NSString stringWithFormat:NSLocalizedString(@"Trust request from uncertified host \\U201C%@\\U201D.", @"teleport trust request title - uncertified version"), [_demandingHost computerName]];
		textString = NSLocalizedString(@"This will allow the demanding host to take control of your mouse and keyword. Warning: the keystrokes and transfers will be sent clear on your network. You should enable encryption on both Macs to encrypt these.\nIf you didn't request the control, you should Reject it.", nil);
	}
	
	NSAlert * authenticationAlert;
	authenticationAlert = [NSAlert alertWithMessageText:msgString
										  defaultButton:NSLocalizedString(@"Accept", nil)
										alternateButton:NSLocalizedString(@"Reject", nil)
											otherButton:NSLocalizedString(@"Accept and Reject Others", nil)
							  informativeTextWithFormat:@"%@", textString];
	
	int result = [(TPMainController*)[NSApp delegate] presentAlert:authenticationAlert];
	
	switch(result) {
		case NSAlertDefaultReturn:
			return TPAuthenticationAcceptedResult;
		case NSAlertAlternateReturn:
			return TPAuthenticationRejectedResult;
		case NSAlertOtherReturn:
			return TPAuthenticationAcceptedAndRejectOthersResult;
		case NSRunAbortedResponse:
			return TPAuthenticationAbortedResult;
	}
	
	return TPAuthenticationRejectedResult;
}

- (void)connection:(TPNetworkConnection*)connection receivedMessage:(TPMessage*)message
{
	TPMsgType type = [message msgType];

	switch(type) {
		case TPAuthenticationAbortMsgType:
			[NSApp abortModal];
			break;
		default:
			break;
	}
}

- (void)connectionDisconnected:(TPNetworkConnection*)connection
{
	[NSApp abortModal];
}

- (TPNetworkConnection*)connection
{
	return _connection;
}

- (TPRemoteHost*)demandingHost
{
	return _demandingHost;
}

@end
