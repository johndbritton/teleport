//
//  TPHotBorderView.m
//  teleport
//
//  Created by JuL on 08/02/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import "TPHotBorderView.h"

#import "TPPreferencesManager.h"
#import "TPHotBorder.h"

NSColor * _highlightColor = nil;
NSColor * _transparentColor = nil;
NSColor * _visibleColor = nil;

#define ANIMATION_TIME 2.0

@implementation TPHotBorderView

+ (void)initialize
{
	if(self == [TPHotBorderView class]) {
		_highlightColor = [NSColor redColor];
		_visibleColor = [NSColor blueColor];
		_transparentColor = nil;
	}
}

- (NSColor*)normalColor
{
	static NSColor * _normalColor = nil;
	if(_normalColor == nil) {
		if(DEBUG_HOTBORDER || [[TPPreferencesManager sharedPreferencesManager] boolForPref:@"visibleBorders"])
			_normalColor = _visibleColor;
		else
			_normalColor = _transparentColor;
	}
	
	return _normalColor;
}

- (instancetype)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self setColor:[self normalColor]];
		_animationTimer = nil;	
	}
	return self;
}

- (void)dealloc
{
	if(_animationTimer) {
		[_animationTimer invalidate];
	}
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	return [(id)[self window] draggingEntered:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[(id)[self window] draggingExited:sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	PRINT_ME;
	return YES;
}
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	PRINT_ME;
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	PRINT_ME;
}

- (void)fireAtLocation:(NSPoint)location
{
	if(_animationTimer) {
		[_animationTimer invalidate];
		_animationTimer = nil;
	}
	
	NSDate * now = [[NSDate alloc] init];
	_animationTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(_animationStep) userInfo:now repeats:YES];
}

- (void)_animationStep
{
	NSDate * start = [_animationTimer userInfo];
	NSTimeInterval elapsed = - [start timeIntervalSinceNow];
	float progress = elapsed / ANIMATION_TIME;
	
	
	if(progress >= 1.0) {
		[self stopAnimation];
	}
	else {
		[self setColor:[_highlightColor blendedColorWithFraction:progress ofColor:[self normalColor]]];
	}

	[self display];
}

- (void)setColor:(NSColor*)color
{
	if(color != _color) {
		_color = color;
	}
}

- (void)stopAnimation
{
	[_animationTimer invalidate];
	_animationTimer = nil;
	[self setColor:[self normalColor]];

	[self window];
}

- (void)drawRect:(NSRect)rect
{
	[_color set];
	NSRectFill(rect);
}

@end
