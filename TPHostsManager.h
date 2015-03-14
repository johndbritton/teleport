//
//  TPHostsManager.h
//  teleport
//
//  Created by JuL on 30/01/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TPRemoteHost.h"

extern NSString * TPHostsKey;
extern NSString * TPHostsConfigurationDidChangeNotification;

@interface TPHostsManager : NSObject
{
	NSMutableDictionary * _hosts;
	NSMutableDictionary * _clientHosts;
	
	TPRemoteHost * _pendingAuthenticationHost;
}

+ (TPHostsManager*)defaultManager;

/* Persistence */
- (void)loadHosts;
- (void)saveHosts;

/* Add/remove */
//- (void)addRemoteHost:(TPRemoteHost*)host;
//- (void)removeRemoteHost:(TPRemoteHost*)host;
- (void)addBonjourHost:(TPRemoteHost*)bonjourHost;
- (void)removeBonjourHost:(TPRemoteHost*)bonjourHost;
- (TPRemoteHost*)updatedHostFromData:(NSData*)hostData;

- (void)addClientHost:(TPRemoteHost*)clientHost;

/* Queries */
- (NSArray*)hostsWithState:(TPHostState)state;
- (TPRemoteHost*)hostWithIdentifier:(NSString*)identifier;
- (TPRemoteHost*)hostWithAddress:(NSString*)address;

/* Misc */
- (void)notifyChanges;

@end
