//
//  TPPreferencesManager.m
//  teleport
//
//  Created by JuL on 11/08/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import "TPPreferencesManager.h"
#import "TPLocalHost.h"

#include <unistd.h>

#if DEBUG_BUILD || PRERELEASE_BUILD

NSString * TPDefaultsWillChangeNotification = @"TPDefaultsWillChangeDebugNotification";
NSString * TPDefaultsDidChangeNotification = @"TPDefaultsDidChangeDebugNotification";
NSString * TPDefaultsChangeNotification = @"TPDefaultsChangeDebugNotification";

NSString * TPPreferencesDidUpgradeNotification = @"TPPreferencesDidUpgradeDebugNotification";

#else

NSString * TPDefaultsWillChangeNotification = @"TPDefaultsWillChangeNotification";
NSString * TPDefaultsDidChangeNotification = @"TPDefaultsDidChangeNotification";
NSString * TPDefaultsChangeNotification = @"TPDefaultsChangeNotification";

NSString * TPPreferencesDidUpgradeNotification = @"TPPreferencesDidUpgradeNotification";

#endif

NSString * TPPreferencesPreviousVersionKey = @"TPPreferencesPreviousVersionKey";

static TPPreferencesManager * _sharedPreferencesManager = nil;

@interface NSUserDefaults (Private)

+ (void)setStandardUserDefaults:(NSUserDefaults *)sud;

@end

@implementation NSObject (PreferencesAdditions)

- (void)bind:(NSString*)binding toPref:(NSString*)prefKey
{
	[self bind:binding toObject:[TPPreferencesManager sharedPreferencesManager] withKeyPath:prefKey options:nil];
}

@end

@interface TPPreferencesManager (Private)

@property (nonatomic, readonly, strong) NSUserDefaultsController *_defaultsController;

@end

@implementation NSString (PreferencesAdditions)

- (BOOL)boolValue
{
	NSString * lowercaseString = [self lowercaseString];
	return [lowercaseString isEqualToString:@"yes"] || [lowercaseString isEqualToString:@"true"] || [lowercaseString isEqualToString:@"1"];
}

@end

@implementation TPPreferencesManager

+ (TPPreferencesManager*)sharedPreferencesManager
{
	if(_sharedPreferencesManager == nil)
		_sharedPreferencesManager = [[TPPreferencesManager alloc] init];
	return _sharedPreferencesManager;
}

- (instancetype) init
{
	self = [super init];
	
	NSString * appDomainName = [[NSBundle mainBundle] bundleIdentifier];
	NSString * domainName = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
	_isLocal = [domainName isEqualToString:appDomainName];
	
	if(_isLocal) {
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(changeDefault:) name:TPDefaultsChangeNotification object:nil];
	}
	else {
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsWillChange:) name:TPDefaultsWillChangeNotification object:nil];
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsDidChange:) name:TPDefaultsDidChangeNotification object:nil];
	}
	
	return self;
}

- (void)dealloc
{
	if(_isLocal) {
		[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:TPDefaultsChangeNotification object:nil];
	}
	else {
		[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:TPDefaultsWillChangeNotification object:nil];
		[[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:TPDefaultsDidChangeNotification object:nil];
	}
}

- (BOOL)isLocal
{
	return _isLocal;
}

- (NSUserDefaultsController*)_defaultsController
{
	static NSUserDefaultsController * _userDefaultsController = nil;
	
	if(_userDefaultsController == nil) {
		NSString * appDomainName = [[NSBundle mainBundle] bundleIdentifier];
		NSString * domainName = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
		NSUserDefaults * defaults = [[NSUserDefaults alloc] init];
		
		if (![appDomainName isEqualToString:domainName]) {
			[defaults removeSuiteNamed:appDomainName];
			[defaults addSuiteNamed:domainName];
		}
		
		_userDefaultsController = [[NSUserDefaultsController alloc] initWithDefaults:defaults initialValues:nil];
		
		[_userDefaultsController setInitialValues:@{SHARE_PASTEBOARD: @YES,
												   SYNC_LOCK_STATUS: @NO,
												   SYNC_SLEEP_STATUS: @NO,
												   ALLOW_CONTROL: @NO,
												   REQUIRE_KEY: @NO,
												   DELAYED_SWITCH: @NO,
												   SWITCH_DELAY: @0.5f,
												   SWITCH_WITH_DOUBLE_TAP: @NO,
												   LIMIT_PASTEBOARD_SIZE: @YES,
												   MAX_PASTEBOARD_SIZE: @1024,
												   AUTOCHECK_VERSION: @YES,
												   /* Secret stuff */
												   HIDE_CONTROL_BEZEL: @NO,
												   @"visibleBorders": @NO,
												   INHIBITION_PERIOD: @0.2f,
												   SYNC_FIND_PASTEBOARD: @NO,
												   WARNED_ABOUT_ACCESSIBILITY: @NO,
#if DEBUG_BUILD || PRERELEASE_BUILD
												   COMMAND_PORT: @44276,
												   TRANSFER_PORT: @44277,
#else
												   COMMAND_PORT: @44176,
												   TRANSFER_PORT: @44177,
#endif
												   TRUST_REQUEST_BEHAVIOR: @(TRUST_REQUEST_ASK),
												   ENABLED_ENCRYPTION: @([[TPLocalHost localHost] hasIdentity]),
												   SWITCH_KEY_TAG: @ALT_KEY_TAG,
												   COPY_FILES: @YES,
												   REQUIRE_PASTEBOARD_KEY: @NO,
												   PASTEBOARD_KEY_TAG: @COMMAND_KEY_TAG,
												   WAKE_ON_LAN: @NO,
												   TRUST_LOCAL_CERTIFICATE: @YES,
												   SHOW_SWITCH_ANIMATION: @YES,
												   DOUBLE_TAP_INTERVAL: @0.5f,
												   SHOW_TEXTUAL_STATUS: @YES,
												   TIGER_BEHAVIOR: @NO,
												   ADD_TO_LOGIN_ITEMS: @YES,
												   DISCONNECT_ON_NETWORK_CONFIG_CHANGE: @NO,
												   WRAP_ON_STOP_CONTROL: @YES,
												   PLAY_SWITCH_SOUND: @NO,
												   SYNC_MODIFIERS: [NSNumber numberWithInt:YES]}];
		
		/* Static prefs */
		if([self isLocal]) {
			int previousVersion = [self intForPref:PREFS_VERSION];
			if(previousVersion != CURRENT_PREFS_VERSION) {
				[self setValue:@CURRENT_PREFS_VERSION forKey:PREFS_VERSION];
				[[NSNotificationCenter defaultCenter] postNotificationName:TPPreferencesDidUpgradeNotification object:self userInfo:@{TPPreferencesPreviousVersionKey: @(previousVersion)}];
			}
		}
		
	}
	
	return _userDefaultsController;
}

- (id)valueForKey:(NSString*)key
{
	return [[self _defaultsController] valueForKeyPath:[NSString stringWithFormat:@"values.%@", key]];
}

- (BOOL)boolForPref:(NSString*)pref
{
	return [[self valueForKey:pref] boolValue];
}

- (int)intForPref:(NSString*)pref
{
	return [[self valueForKey:pref] intValue];
}

- (float)floatForPref:(NSString*)pref
{
	return [[self valueForKey:pref] floatValue];
}

- (id)valueForPref:(NSString*)pref
{
	return [self valueForKey:pref];
}

- (int)portForPref:(NSString*)pref
{
	if([pref isEqualToString:TRANSFER_PORT])
		return [self portForPref:COMMAND_PORT] + 1;
	else
		return [self intForPref:pref];
}

- (void)setValue:(id)value forKey:(NSString*)key
{
	if(_isLocal) {
		NSUserDefaultsController * defaultsController = [self _defaultsController];
		[self willChangeValueForKey:key];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:TPDefaultsWillChangeNotification object:key userInfo:nil deliverImmediately:YES];
		[defaultsController setValue:value forKeyPath:[NSString stringWithFormat:@"values.%@", key]];
		[[defaultsController defaults] synchronize];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:TPDefaultsDidChangeNotification object:key userInfo:nil deliverImmediately:YES];
		[self didChangeValueForKey:key];
	}
	else {
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:TPDefaultsChangeNotification object:key userInfo:@{key: value} deliverImmediately:YES];
	}
}

- (void)changeDefault:(NSNotification*)notification
{
	NSString * key = [notification object];
	id value = [notification userInfo][key];
	[self setValue:value forKeyPath:key];
}

- (void)defaultsWillChange:(NSNotification*)notification
{
	NSString * keyPath = [notification object];
	[self willChangeValueForKey:keyPath];
}

- (void)defaultsDidChange:(NSNotification*)notification
{
	NSString * keyPath = [notification object];
	[[[self _defaultsController] defaults] synchronize];
	[self didChangeValueForKey:keyPath];
}

- (BOOL)event:(NSEvent*)event hasRequiredKeyIfNeeded:(NSString*)boolPref withTag:(NSString*)tagPref
{
	if(![self boolForPref:boolPref])
		return YES;
	
	unsigned int keyMask = NSEventMaskFromType([self intForPref:tagPref]);
	return (([event modifierFlags] & keyMask) != 0);
}

@end
