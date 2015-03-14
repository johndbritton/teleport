//
//  PTKeyBroadcaster.m
//  Protein
//
//  Created by Quentin Carnicelli on Sun Aug 03 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import "PTKeyBroadcaster.h"
#import "PTKeyCombo.h"
#import <Carbon/Carbon.h>

NSString* PTKeyBroadcasterKeyEvent = @"PTKeyBroadcasterKeyEvent";

@implementation PTKeyBroadcaster

- (void)_bcastKeyCode: (short)keyCode modifiers: (long)modifiers
{
	PTKeyCombo* keyCombo = [PTKeyCombo keyComboWithKeyCode: keyCode modifiers: modifiers];
	NSDictionary* userInfo = @{@"keyCombo": keyCombo};

	[[NSNotificationCenter defaultCenter]
		postNotificationName: PTKeyBroadcasterKeyEvent
		object: self
		userInfo: userInfo];
}

- (BOOL)_bcastEvent: (NSEvent*)event
{
	NSString * string = [event charactersIgnoringModifiers];
	long modifiers = [event modifierFlags];
	
	if([string length] > 0) {
		unichar c = [string characterAtIndex:0];
		switch(c) {
			case '\n':
			case '\r':
			case 3: // enter
			case 27: // escape
				if((modifiers & NSDeviceIndependentModifierFlagsMask) == 0) {
					return NO;
				}
			default:
				break;
		}
	}
	
	short keyCode = [event keyCode];
	
	modifiers = [[self class] cocoaModifiersAsCarbonModifiers: modifiers];
	
	[self _bcastKeyCode: keyCode modifiers: modifiers];
	
	return YES;
}

- (void)keyDown: (NSEvent*)event
{
	if(![self _bcastEvent: event]) {
		[super keyDown:event];
	}
}

- (BOOL)performKeyEquivalent: (NSEvent*)event
{
	[self _bcastEvent: event];
	return YES;
}

+ (long)cocoaModifiersAsCarbonModifiers: (long)cocoaModifiers
{
	static long cocoaToCarbon[6][2] =
	{
		{ NSCommandKeyMask, cmdKey},
		{ NSAlternateKeyMask, optionKey},
		{ NSControlKeyMask, controlKey},
		{ NSShiftKeyMask, shiftKey},
		{ NSFunctionKeyMask, rightControlKey},
		//{ NSAlphaShiftKeyMask, alphaLock }, //Ignore this?
	};

	long carbonModifiers = 0;
	int i;
	
	for( i = 0 ; i < 6; i++ )
		if( cocoaModifiers & cocoaToCarbon[i][0] )
			carbonModifiers += cocoaToCarbon[i][1];
	
	return carbonModifiers;
}


@end
