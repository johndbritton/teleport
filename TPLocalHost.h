//
//  TPLocalHost.h
//  teleport
//
//  Created by JuL on Fri Feb 27 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TPHost.h"

@interface TPLocalHost : TPHost
{
	NSArray * _potentialIdentities;
	NSMutableArray * _backgroundImages;
}

+ (TPLocalHost*)localHost;

@property (nonatomic, readonly, copy) NSArray *potentialIdentities;
@property (nonatomic) SecIdentityRef identity;
@property (nonatomic, readonly) BOOL hasIdentity;
- (void)resetIdentity;
- (void)reloadIdentity;

@property (nonatomic, readonly, copy) NSString *bonjourName;

@property (nonatomic, readonly, strong) NSScreen *mainScreen;
- (NSScreen*)sharedScreen;
- (void)setSharedScreenIndex:(unsigned)screenIndex;
- (unsigned)sharedScreenIndex;
- (void)wakeUpScreen;
- (void)sleepScreen;

- (NSImage*)backgroundImageForScreen:(NSScreen*)screen;

- (void)checkCapabilities;

@property (nonatomic, getter=isAccessibilityAPIEnabled, readonly) BOOL accessibilityAPIEnabled;
@property (nonatomic, readonly) BOOL checkAccessibility;

@end
