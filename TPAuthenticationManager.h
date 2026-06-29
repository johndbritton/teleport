//
//  TPAuthenticationManager.h
//  teleport
//
//  Created by JuL on Thu Mar 04 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPAuthenticationRequest.h"

@class TPRemoteHost, TPNetworkConnection;

@interface TPAuthenticationManager : NSObject
{
	NSMutableArray * _trustedHosts;
	TPNetworkConnection * _currentConnection;
}

+ (TPAuthenticationManager*)defaultManager;

/* Persistence */
- (void)loadHosts;
- (void)saveHosts;

/* Authentication requests - client side */
- (BOOL)requestAuthenticationOnHost:(TPRemoteHost*)host;
- (void)abortAuthenticationRequest;

/* Authentication answer - server side */
- (void)authenticationRequestedFromHost:(TPRemoteHost*)host onConnection:(TPNetworkConnection*)connection;
- (void)replyToAuthenticationRequest:(TPAuthenticationRequest*)authRequest withResult:(TPAuthenticationResult)result;

/* Trusted hosts */
@property (nonatomic, readonly, copy) NSArray *trustedHosts;
- (void)host:(TPRemoteHost*)remoteHost setTrusted:(BOOL)trusted;
- (BOOL)isHostTrusted:(TPRemoteHost*)remoteHost;

@end
