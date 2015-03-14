//
//  TPHostsManager.m
//  teleport
//
//  Created by JuL on 30/01/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import "TPHostsManager.h"

#import "TPLocalHost.h"
#import "TPClientController.h"
#import "TPNetworkConnection.h"
#import "TPAuthenticationManager.h"
#import "TPPreferencesManager.h"
#import "TPMessage.h"

#define DUPLICATE 0
#define HOSTS_VERSION 6

NSString * TPHostsVersionKey = @"TPHostsVersion";
NSString * TPHostsKey = @"TPHosts";
NSString *TPHostsConfigurationDidChangeNotification = @"TPHostsConfigurationDidChangeNotification";

static TPHostsManager * _defaultHostsManager = nil;

@implementation TPHostsManager

+ (TPHostsManager*)defaultManager
{
	if(_defaultHostsManager == nil)
		_defaultHostsManager = [[TPHostsManager alloc] init];
	
	return _defaultHostsManager;
}

- (instancetype) init
{
	self = [super init];
	
	_hosts = [[NSMutableDictionary alloc] init];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyChanges) name:TPHostDidUpdateNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveHosts) name:TPHostDidUpdateNotification object:nil];
	
	return self;
}



#pragma mark -
#pragma mark Persistence

- (void)loadHosts
{
	int hostsVersion = [[TPPreferencesManager sharedPreferencesManager] intForPref:TPHostsVersionKey];
	if(hostsVersion != HOSTS_VERSION)
		return;
	
	NSData * archivedData = [[TPPreferencesManager sharedPreferencesManager] valueForPref:TPHostsKey];
	if(archivedData != nil) {
		[_hosts removeAllObjects];
		NSArray * newHosts = nil;
		@try {
			newHosts = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
		}
		@catch(NSException * e) {
			newHosts = nil;
		}
		
		if(newHosts != nil) {
			NSEnumerator * newHostsEnum = [newHosts objectEnumerator];
			TPRemoteHost * newHost;
			
			while((newHost = [newHostsEnum nextObject])) {
				TPHostState state = [newHost hostState];
				
				switch(state) {
					case TPHostSharedState:
					case TPHostIncompatibleState:
						break;
					case TPHostUndefState:
					case TPHostPeeredOfflineState:
						_hosts[[newHost identifier]] = newHost;
						break;
					case TPHostPeeredOnlineState:
					case TPHostControlledState:
						[newHost setHostState:TPHostPeeredOfflineState];
						_hosts[[newHost identifier]] = newHost;
						break;
					default:
						break;
				}
			}
		}
	}
}

- (void)saveHosts
{
	NSMutableDictionary * hostsToSave = [_hosts mutableCopy];
	NSEnumerator * hostsEnum = [_hosts objectEnumerator];
	TPRemoteHost * host;
	
	while((host = [hostsEnum nextObject])) {
		TPHostState state = [host hostState];
		
		switch(state) {
			case TPHostSharedState:
			case TPHostIncompatibleState:
			case TPHostUndefState:
				[hostsToSave removeObjectForKey:[host identifier]];
				break;
			default:
				break;
		}
	}
	
	[[TPPreferencesManager sharedPreferencesManager] setValue:[NSKeyedArchiver archivedDataWithRootObject:hostsToSave] forKey:TPHostsKey];
	[[TPPreferencesManager sharedPreferencesManager] setValue:@HOSTS_VERSION forKey:TPHostsVersionKey];
	
}


#pragma mark -
#pragma mark Setters

//- (void)addRemoteHost:(TPRemoteHost*)host
//{
//	TPRemoteHost * knownHost = [self hostWithIdentifier:[host identifier]];
//	BOOL shouldNotify = YES;
//	
//	DebugLog(@"new host: %@%@", host, knownHost?@" (known)":@"");
//	
//	if(knownHost != nil) {
//		if([host address] != nil && [knownHost address] == nil) {
//			[knownHost setAddress:[host address]];
//			[knownHost setScreenSize:[host screenSize]];
//		}
//	}
//	else
//		[_hosts setObject:host forKey:[host identifier]];
//	
//	if(shouldNotify)
//		[self notifyChanges];
//}

- (void)removeRemoteHost:(TPRemoteHost*)host
{
	TPRemoteHost * knownHost = [self hostWithIdentifier:[host identifier]];
	BOOL shouldNotify = YES;
	
	DebugLog(@"remove host: %@", knownHost);
	
	if(knownHost != nil) {
		TPHostState state = [knownHost hostState];
		
		switch(state) {
			case TPHostUndefState:
				shouldNotify = NO;
				break;
			case TPHostSharedState:
			case TPHostIncompatibleState:
				[knownHost setHostState:TPHostUndefState];
				break;
			case TPHostPeeredOfflineState:
				shouldNotify = NO;
				DebugLog(@"error: offline peered host disappeared on rdv");
				break;
			case TPHostPeeredOnlineState:
				[knownHost setHostState:TPHostPeeredOfflineState];
				break;
			case TPHostControlledState:
				[knownHost setHostState:TPHostPeeredOfflineState];
				[[TPClientController defaultController] stopControl];
				break;
			default:
				break;
		}
	}
	else
		shouldNotify = NO;
	
	if(shouldNotify)
		[self notifyChanges];
}

- (void)addBonjourHost:(TPRemoteHost*)bonjourHost
{
	TPRemoteHost * knownHost = [self hostWithIdentifier:[bonjourHost identifier]];
	BOOL shouldNotify = YES;
	
	DebugLog(@"new bonjour host: %@%@", bonjourHost, knownHost?@" (known)":@"");
	
	if(knownHost != nil) {
		if([bonjourHost address] != nil) {
			TPHostState state = [knownHost hostState];
			
			[knownHost setAddress:[bonjourHost address]];
			[knownHost setPort:[bonjourHost port]];
			[knownHost setScreens:[bonjourHost screens]];
			
			switch(state) {
				case TPHostUndefState:
					[knownHost setHostState:TPHostSharedState];
					break;
				case TPHostSharedState:
					shouldNotify = NO;
					break;
				case TPHostPeeredOfflineState:
					[knownHost setHostState:TPHostPeeredOnlineState];
					break;
				case TPHostPeeredOnlineState:
					break;
				case TPHostControlledState:
					break;
				default:
					break;
			}
		}
		else {
			[knownHost setHostState:TPHostIncompatibleState];
		}
	}
	else {
		_hosts[[bonjourHost identifier]] = bonjourHost;
#if DUPLICATE
		int i;
		for(i=0; i<DUPLICATE; i++) {
			TPRemoteHost * fakeHost = [bonjourHost copy];
			NSString * identifier = [[bonjourHost identifier] stringByAppendingString:[NSString stringWithFormat:@"%d", i]];
			[fakeHost setIdentifier:identifier];
			[fakeHost setHostState:TPHostOnlineState];
			[_hosts setObject:fakeHost forKey:identifier];
			[fakeHost release];
		}
#endif
	}
	
	if(shouldNotify)
		[self notifyChanges];
}

- (void)removeBonjourHost:(TPRemoteHost*)bonjourHost
{
	[self removeRemoteHost:bonjourHost];
}

- (TPRemoteHost*)updatedHostFromData:(NSData*)hostData
{
	TPRemoteHost * host = (TPRemoteHost*)[TPRemoteHost hostFromHostData:hostData];
	TPRemoteHost * knownHost = [self hostWithIdentifier:[host identifier]];
	
	if(knownHost != nil) {
		[knownHost setComputerName:[host computerName]];
		[knownHost setCapabilities:[host capabilities]];
		[knownHost setMACAddress:[host MACAddress]];
		[knownHost setOSVersion:[host osVersion]];
		
		return knownHost;
	}
	else
		return host;
}

- (void)addClientHost:(TPRemoteHost*)clientHost
{
	if(_clientHosts == nil) {
		_clientHosts = [[NSMutableDictionary alloc] init];
	}
	
	_clientHosts[[clientHost identifier]] = clientHost;
}


#pragma mark -
#pragma mark Getters

- (NSArray*)hostsWithState:(TPHostState)state
{
	return [[_hosts allValues] hostsWithState:state];
}

- (TPRemoteHost*)hostWithIdentifier:(NSString*)identifier
{
	return _hosts[identifier];
}

- (TPRemoteHost*)hostWithAddress:(NSString*)address
{
	NSEnumerator * hostEnum = [_hosts objectEnumerator];
	TPRemoteHost * host;
	
	while((host = [hostEnum nextObject])) {
		if(![host isKindOfClass:[TPRemoteHost class]])
			continue;
		if([[host address] isEqualToString:address])
			return host;
	}
	
	hostEnum = [_clientHosts objectEnumerator];
	while((host = [hostEnum nextObject])) {
		if(![host isKindOfClass:[TPRemoteHost class]])
			continue;
		if([[host address] isEqualToString:address])
			return host;
	}
	
	return nil;
}


#pragma mark -
#pragma mark Misc

- (void)notifyChangesNow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:TPHostsConfigurationDidChangeNotification object:nil userInfo:nil];
}

- (void)notifyChanges
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(notifyChangesNow) object:nil];
	[self performSelector:@selector(notifyChangesNow) withObject:nil afterDelay:0.1];
}

@end
