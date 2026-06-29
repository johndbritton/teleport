//
//  TPAnimationManager.h
//  teleport
//
//  Created by Julien Robert on 16/01/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface NSObject (TPAnimationManagerDelegate)

- (void)animationDidComplete;

@end

@interface TPAnimationManager : NSObject <CAAnimationDelegate>
{
	id _delegate;
	int _step;
}

+ (NSRect)rect:(NSRect)rect centeredAtPoint:(NSPoint)point;
+ (NSRect)rect:(NSRect)rect snappedInsideRect:(NSRect)containingRect margin:(float)margin;

+ (void)flipAnimationFromView:(NSView*)initialView toView:(NSView*)finalView invertRotation:(BOOL)invertRotation delegate:(id)delegate;

@end
