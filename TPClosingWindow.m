//
//  TPClosingWindow.m
//  teleport
//
//  Created by JuL on Mon Jan 26 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPClosingWindow.h"
#import "TPPreferencePane.h"

@implementation TPClosingWindow

- (void)keyDown:(NSEvent*)event
{
	//DebugLog(@"keyDown");
	[(id)[self delegate] closeAboutSheet];
}

- (void)mouseDown:(NSEvent*)event
{
	[(id)[self delegate] closeAboutSheet];
}

@end
