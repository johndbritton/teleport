//
//  TPAuthenticationRequest.h
//  teleport
//
//  Created by JuL on 28/02/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

typedef NS_ENUM(NSInteger, TPAuthenticationResult) {
	TPAuthenticationAcceptedResult,
	TPAuthenticationRejectedResult,
	TPAuthenticationAcceptedAndRejectOthersResult,
	TPAuthenticationAbortedResult
	
} ;

@class TPRemoteHost, TPNetworkConnection;

@interface TPAuthenticationRequest : NSObject
{
	TPNetworkConnection * _connection;
	TPRemoteHost * _demandingHost;
}

- (instancetype) initWithNetworkConnection:(TPNetworkConnection*)connection demandingHost:(TPRemoteHost*)demandingHost NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) TPAuthenticationResult ask;

@property (nonatomic, readonly, strong) TPNetworkConnection *connection;
@property (nonatomic, readonly, strong) TPRemoteHost *demandingHost;

@end
