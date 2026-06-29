//
//  TPConnectionsManager.h
//  teleport
//
//  Created by JuL on 24/02/06.
//  Copyright 2006 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TPNetworkConnection.h"

@class TPTCPSecureSocket;

@interface TPConnectionsManager : NSObject
{
	NSMutableSet * _connections;
	NSMutableDictionary * _pendingConnections;
	TPTCPSecureSocket * _listenSocket;
	id _listenDelegate;
}

+ (TPConnectionsManager*)manager;

- (BOOL)connectToHost:(TPRemoteHost*)host withDelegate:(id)delegate infoDict:(NSDictionary*)infoDict;

- (BOOL)startListeningWithDelegate:(id)delegate onPort:(int*)port;
- (void)stopListening;

- (BOOL)wakeUpHost:(TPRemoteHost*)host;

@end

@interface NSObject (TPConnectionsManager_delegate)

- (void)connectionToServerSucceeded:(TPNetworkConnection*)networkConnection infoDict:(NSDictionary*)infoDict;
- (void)connectionToServerFailed:(TPRemoteHost*)host infoDict:(NSDictionary*)infoDict;

- (void)connectionFromClientAccepted:(TPNetworkConnection*)networkConnection;

@end
