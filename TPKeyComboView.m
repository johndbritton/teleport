//
//  TPKeyComboView.m
//  teleport
//
//  Created by Julien Robert on 08/04/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "TPKeyComboView.h"
#import "PTKeyBroadcaster.h"

@implementation TPKeyComboView


- (void)drawRect:(NSRect)rect
{
	BOOL hasFocus = ([[self window] firstResponder] == self);

	[[NSColor whiteColor] set];
	NSRectFill(rect);
	
	if(hasFocus) {
		[[NSColor keyboardFocusIndicatorColor] set];
		NSFrameRectWithWidthUsingOperation([self bounds], 2.0, NSCompositeSourceOver);
	}
	else {
		[[NSColor lightGrayColor] set];
		NSFrameRect([self bounds]);
	}
	
	NSString * string = nil;
	NSColor * color = nil;
	
	if(_keyCombo == nil) {
		color = [NSColor grayColor];
		
		if(hasFocus) {
			string = NSLocalizedStringFromTableInBundle(@"Type key combo", nil, [NSBundle bundleForClass:[self class]], @"Displayed in the key combo field, should be short");
		}
		else {
			string = NSLocalizedStringFromTableInBundle(@"Click to set", nil, [NSBundle bundleForClass:[self class]], @"Displayed in the key combo field, should be short");
		}
	}
	else {
		color = [NSColor blackColor];
		string = [_keyCombo description];
	}
	
	NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	[paragraphStyle setAlignment:NSCenterTextAlignment];
	NSFont * font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
	NSDictionary * attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
								 paragraphStyle, NSParagraphStyleAttributeName,
								 font, NSFontAttributeName,
								 color, NSForegroundColorAttributeName,
								 nil];
	[string drawInRect:NSInsetRect([self bounds], 2.0, 2.0) withAttributes:attributes];
}

- (void)setDelegate:(id)delegate
{
	_delegate = delegate;
}

- (id)delegate
{
	return _delegate;
}

- (void)setKeyCombo:(PTKeyCombo*)keyCombo
{
	if(keyCombo != _keyCombo) {
		_keyCombo = keyCombo;
		
		[self setNeedsDisplay:YES];
	}
}

- (PTKeyCombo*)keyCombo
{
	return _keyCombo;
}

- (void)_updateKeyComboWithEvent:(NSEvent*)event
{
	BOOL updateKeyCombo = YES;
	PTKeyCombo * keyCombo = nil;
	unsigned short keyCode = [event keyCode];
	
	switch(keyCode) {
		case 51: // backspace: clear
			break;
		case 53: // escape: exit
			updateKeyCombo = NO;
			break;
		default:
			keyCombo = [PTKeyCombo keyComboWithKeyCode:keyCode modifiers:[PTKeyBroadcaster cocoaModifiersAsCarbonModifiers:[event modifierFlags]]];
			
			if(![keyCombo isValidHotKeyCombo]) {
				NSBeep();
				return;
			}
	}
	
	if(updateKeyCombo) {
		[self setKeyCombo:keyCombo];
		
		if(_delegate != nil && [_delegate respondsToSelector:@selector(keyComboDidChange:)])
			[_delegate keyComboDidChange:keyCombo];		
	}
	
	[[self window] makeFirstResponder:[self superview]];
}

- (void)keyDown:(NSEvent*)event
{
	[self _updateKeyComboWithEvent:event];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	[self setNeedsDisplay:YES];
	return YES;
}

- (BOOL)resignFirstResponder
{
	[self setNeedsDisplay:YES];
	return YES;
}

@end
