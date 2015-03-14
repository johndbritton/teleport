//
//  TPScreen.h
//  teleport
//
//  Created by Julien Robert on 17/06/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TPScreen : NSScreen
{
	NSRect _tpFrame;
}

- (void)setFrame:(NSRect)frame;

+ (NSString*)stringFromScreens:(NSArray*)screens;
+ (NSArray*)screensFromString:(NSString*)screensString;

@end
