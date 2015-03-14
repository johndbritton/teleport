//
//  TPHotBorderView.h
//  teleport
//
//  Created by JuL on 08/02/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TPHotBorderView : NSView
{
	NSTimer * _animationTimer;
	NSColor * _color;
}

- (void)fireAtLocation:(NSPoint)location;

@property (nonatomic, readonly, copy) NSColor *normalColor;
- (void)setColor:(NSColor*)color;

- (void)stopAnimation;

@end
