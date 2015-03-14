//
//  TPScreen.m
//  teleport
//
//  Created by Julien Robert on 17/06/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "TPScreen.h"

@implementation TPScreen

- (BOOL)isEqual:(NSScreen*)screen
{
	if(screen == nil || ![screen isKindOfClass:[NSScreen class]]) {
		return NO;
	}
	else {
		return NSEqualRects([self frame], [screen frame]);
	}
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"Screen %@", NSStringFromRect([self frame])];
}

- (void)setFrame:(NSRect)frame
{
	_tpFrame = frame;
}

- (NSRect)frame
{
	return _tpFrame;
}

+ (NSString*)stringFromScreens:(NSArray*)screens
{
	NSMutableString * screenSizesString = [[NSMutableString alloc] init];
	NSEnumerator * screenEnum = [screens objectEnumerator];
	NSScreen * screen;
	
	while((screen = [screenEnum nextObject]) != nil) {
		NSString * screenString = NSStringFromRect([screen frame]);
		if(screen != [screens lastObject]) {
			[screenSizesString appendFormat:@"%@;", screenString];
		}
		else {
			[screenSizesString appendFormat:@"%@", screenString];
		}
	}
	
	return screenSizesString;
}

+ (NSArray*)screensFromString:(NSString*)screensString
{
	NSMutableArray * screens = [[NSMutableArray alloc] init];
	NSArray * screenStrings = [screensString componentsSeparatedByString:@";"];
	NSEnumerator * screenStringsEnum = [screenStrings objectEnumerator];
	NSString * screenString;
	
	while((screenString = [screenStringsEnum nextObject]) != nil) {
		TPScreen * screen = [[TPScreen alloc] init];
		[screen setFrame:NSRectFromString(screenString)];
		[screens addObject:screen];
	}
	
	return screens;
}

@end
