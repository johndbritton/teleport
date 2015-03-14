//
//  TPTestsController.m
//  teleport
//
//  Created by JuL on 09/11/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import "TPTestsController.h"

#import "TPFakeHostsGenerator.h"

#import "TPLocalHost.h"
#import "TPRemoteHost.h"
#import "TPEventTapsController.h"
#import "TPMessage.h"

@interface TPTestsController (Tests)

+ (void)_testArchiving;
+ (void)_testEventTaps;
+ (void)_testFolderSize;

@end


@implementation TPTestsController

+ (void)runTests
{
	NSLog(@"===== RUNING TESTS =====");
//	[TPTestSocket test];
//	[[TPSecurityManager defaultManager] testSecurity];
	[self _testArchiving];
	[self _testFolderSize];
//	[self _testEventTaps];
}

+ (void)runFakeHostsTest
{
	TPFakeHostsGenerator * generator = [[TPFakeHostsGenerator alloc] init];
	[generator run];
}

+ (void)_testArchiving
{

}

+ (void)_testEventTaps
{
	[[TPEventTapsController defaultController] startGettingEventsForListener:nil onScreen:[[TPLocalHost localHost] mainScreen]];
}

+ (void)_testSizeOfPath:(NSString*)path
{
	BOOL smaller = [[NSFileManager defaultManager] isTotalSizeOfItemAtPath:path smallerThan:1*1024*1024*1024];
	NSLog(@"path: %@ smaller: %d", path, smaller);
}

+ (void)_testFolderSize
{
	NSString * desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
	[self _testSizeOfPath:desktopPath];
	[self _testSizeOfPath:[desktopPath stringByAppendingPathComponent:@"IT Crowd"]];
	[self _testSizeOfPath:[desktopPath stringByAppendingPathComponent:@"dts-demo-dvd9.jpg"]];
}

@end
