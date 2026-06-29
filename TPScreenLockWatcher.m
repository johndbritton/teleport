//
//  TPScreenLockWatcher.m
//  teleport
//
//  Created by benny on 2025/6/24.
//

#import "TPScreenLockWatcher.h"
#import "common.h"

#define KEY_SCREEN_LOCKED @"com.apple.screenIsLocked"
#define KEY_SCREEN_UNLOCKED @"com.apple.screenIsUnlocked"

static TPScreenLockWatcher *defaultWatcher;

static BOOL isScreenLocked(void) {
	CFDictionaryRef sessionInfo = CGSessionCopyCurrentDictionary();
	if (!sessionInfo) return NO;

	CFBooleanRef locked = CFDictionaryGetValue(sessionInfo, CFSTR("CGSSessionScreenIsLocked"));
	BOOL result = (locked == kCFBooleanTrue);
	CFRelease(sessionInfo);
	return result;
}

@interface TPScreenLockWatcher()
@property (readonly) BOOL isLocked;
@property (strong) id lockObserver;
@property (strong) id unlockObserver;
@end

@implementation TPScreenLockWatcher

- (instancetype)init
{
	self = [super init];
	if (self) {
		self.lockObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:KEY_SCREEN_LOCKED
																	 object:nil
																	  queue:[NSOperationQueue mainQueue]
																 usingBlock:^(NSNotification * _Nonnull note) {
			DebugLog(@"Screen locked");
			self->_isLocked = YES;
		}];

		self.unlockObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:KEY_SCREEN_UNLOCKED
																	 object:nil
																	  queue:[NSOperationQueue mainQueue]
																 usingBlock:^(NSNotification * _Nonnull note) {
			DebugLog(@"Screen unlocked");
			self->_isLocked = NO;
		}];
		
		_isLocked = isScreenLocked();
		
		DebugLog(@"Screen isLocked=%@ from init.", @(_isLocked));
	}
	return self;
}

- (void)dealloc
{
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self.lockObserver];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self.unlockObserver];
}

+(BOOL) isLocked {
	if (defaultWatcher == nil) {
		defaultWatcher = [[TPScreenLockWatcher alloc] init];
	}
	return defaultWatcher.isLocked;
}
@end
