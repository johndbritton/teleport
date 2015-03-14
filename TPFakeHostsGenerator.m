//
//  TPFakeHostsGenerator.m
//  teleport
//
//  Created by Julien Robert on 01/05/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TPFakeHostsGenerator.h"
#import "TPHostsManager.h"

#define SCREEN_SIZES (sizeof(TPScreenSizes) / sizeof(NSSize))

static NSSize TPScreenSizes[] = {
	{640.0, 480.0},
	{800.0, 600.0},
	{1024.0, 768.0},
	{1280.0, 1024.0},
	{1600.0, 1200.0},
	{1680.0, 1050.0},
	{1920.0, 1200.0},
};

@implementation TPFakeHostsGenerator

- (instancetype) init
{
	self = [super init];
	
	_hosts = [[NSMutableArray alloc] init];
	
	return self;
}


- (void)_addFakeHost
{
	static int number = 1;
	TPRemoteHost * host = [[TPRemoteHost alloc] initWithIdentifier:[[NSProcessInfo processInfo] globallyUniqueString] address:[NSString stringWithFormat:@"%ld:%ld:%ld:%ld", random()%255, random()%255, random()%255, random()%255] port:44186];
	
	[host setCapabilities:TPHostEncryptionCapability];
	
	NSRect screenFrame = NSZeroRect;
	screenFrame.size = TPScreenSizes[random() % SCREEN_SIZES];
	
	TPScreen * screen = [[TPScreen alloc] init];
	[screen setFrame:screenFrame];
	NSArray * screens = @[screen];
	[host setScreens:screens];
	
	NSString * computerName = [NSString stringWithFormat:@"Fake Mac %d", number++];
	[host setComputerName:computerName];
	
	[host setHostState:TPHostSharedState];
		
	[[TPHostsManager defaultManager] addBonjourHost:host];
	[_hosts addObject:host];
	
	
//	if(number == 10) {
//		[_timer invalidate];
//	}
}

- (void)_removeRandomFakeHost
{
	if([_hosts count] > 0) {
		TPRemoteHost * host = _hosts[random() % [_hosts count]];
		[[TPHostsManager defaultManager] removeBonjourHost:host];
		[_hosts removeObject:host];
	}
}

- (void)run
{
#if 1
	int i;
	for(i=0; i<10; i++) {
		[self _addFakeHost];
	}
#else
	_timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(_addOrRemoveHost) userInfo:nil repeats:YES];
#endif
}

- (void)_addOrRemoveHost
{
#if 0
	[self _addFakeHost];
#else
	if(random() % 2 == 0) {
		[self _removeRandomFakeHost];
	}
	else {
		[self _addFakeHost];
	}
#endif
}


@end
