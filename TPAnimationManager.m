//
//  TPAnimationManager.m
//  teleport
//
//  Created by Julien Robert on 16/01/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "TPAnimationManager.h"

#import <QuartzCore/QuartzCore.h>

#define FLIP_DURATION ((([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) != 0) ? 5.0 : 0.5)
#define ROTATION_ANGLE M_PI_2

@interface TPAnimationManager ()

- (void)startFlipAnimationFromView:(NSView*)initialView toView:(NSView*)finalView invertRotation:(BOOL)invertRotation delegate:(id)delegate;
- (void)continueFlipAnimationFromAnimation:(CAAnimation*)anim;
- (void)endFlipAnimationFromAnimation:(CAAnimation*)anim;

@end

@implementation TPAnimationManager

+ (NSRect)rect:(NSRect)rect centeredAtPoint:(NSPoint)point
{
	NSRect centeredRect = rect;
	centeredRect.origin.x = point.x - NSWidth(centeredRect)/2.0;
	centeredRect.origin.y = point.y - NSHeight(centeredRect)/2.0;
	return centeredRect;
}

+ (NSRect)rect:(NSRect)rect snappedInsideRect:(NSRect)containingRect margin:(float)margin
{
	NSRect snappedRect = rect;
	NSRect parentRect = NSInsetRect(containingRect, margin, margin);
	
	if(NSContainsRect(parentRect, rect)) {
		return snappedRect;
	}
	
	if(NSWidth(rect) > NSWidth(parentRect) || NSHeight(rect) > NSHeight(parentRect)) {
		return snappedRect;
	}
	
	if(NSMinX(rect) < NSMinX(parentRect)) {
		snappedRect.origin.x = NSMinX(parentRect);
	}
	else if(NSMaxX(rect) > NSMaxX(parentRect)) {
		snappedRect.origin.x = NSMaxX(parentRect) - NSWidth(rect);
	}
	
	if(NSMinY(rect) < NSMinY(parentRect)) {
		snappedRect.origin.y = NSMinY(parentRect);
	}
	else if(NSMaxY(rect) > NSMaxY(parentRect)) {
		snappedRect.origin.y = NSMaxY(parentRect) - NSHeight(rect);
	}
	
	return snappedRect;
}

+ (void)flipAnimationFromView:(NSView*)initialView toView:(NSView*)finalView invertRotation:(BOOL)invertRotation delegate:(id)delegate
{
	TPAnimationManager * manager = [[TPAnimationManager alloc] init];
	[manager startFlipAnimationFromView:initialView toView:finalView invertRotation:invertRotation delegate:delegate];
}

- (void)startFlipAnimationFromView:(NSView*)initialView toView:(NSView*)finalView invertRotation:(BOOL)invertRotation delegate:(id)delegate
{
	_delegate = delegate;
	_step = 0;
	
	[CATransaction begin];
	[CATransaction setValue:@YES forKey:kCATransactionDisableActions];
	
	NSView * rootView = [initialView superview];

	NSRect initialFrame = [initialView frame];
	NSRect finalFrame = [finalView frame];
	NSRect parentFrame = [TPAnimationManager rect:NSInsetRect(NSUnionRect(initialFrame, finalFrame), -5.0, -5.0) centeredAtPoint:NSMakePoint(NSMidX(initialFrame), NSMidY(initialFrame))];
	
	NSView * parentView = [[NSView alloc] initWithFrame:parentFrame];
	[rootView addSubview:parentView];
		
	NSRect parentBounds = [parentView bounds];
	NSPoint centerPoint = NSMakePoint(NSMidX(parentBounds), NSMidY(parentBounds));
	[initialView removeFromSuperview];
	[initialView setFrame:[TPAnimationManager rect:initialFrame centeredAtPoint:centerPoint]];
	[parentView addSubview:initialView];
	
	[finalView removeFromSuperview];
	[finalView setFrame:[TPAnimationManager rect:finalFrame centeredAtPoint:centerPoint]];
	[parentView addSubview:finalView];
	
	CALayer * parentLayer = [parentView layer];
	CALayer * initialLayer = [initialView layer];
	CALayer * finalLayer = [finalView layer];
	
	initialLayer.anchorPoint = CGPointMake(0.5, 0.5);
	initialLayer.frame = NSRectToCGRect([initialView frame]);
	
	finalLayer.anchorPoint = CGPointMake(0.5, 0.5);
	finalLayer.frame = NSRectToCGRect([finalView frame]);
	
	parentLayer.anchorPoint = CGPointMake(0.5, 0.5);
	parentLayer.masksToBounds = NO;
	
	float zDistance = 500;
	CATransform3D sublayerTransform = CATransform3DIdentity; 
	sublayerTransform.m34 = 1. / -zDistance;
	
	parentLayer.sublayerTransform = sublayerTransform;
	parentLayer.frame = NSRectToCGRect([parentView frame]);
	
	CGFloat xRatio = NSWidth(initialFrame)/NSWidth(finalFrame);
	CGFloat yRatio = NSHeight(initialFrame)/NSHeight(finalFrame);
	
	CABasicAnimation * transformAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
	transformAnimation.duration = FLIP_DURATION/2.0;
	transformAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
	
	CGFloat angle = invertRotation ? -ROTATION_ANGLE : ROTATION_ANGLE;
	CATransform3D finalTransform = CATransform3DMakeRotation(angle, 1.0, 0.0, 0.0);
	finalTransform = CATransform3DScale(finalTransform, 0.5 + 1/(2*xRatio), 0.5 + 1/(2*yRatio), 1.0);

	transformAnimation.toValue = [NSValue valueWithCATransform3D:finalTransform];
	transformAnimation.fillMode = kCAFillModeForwards;
	transformAnimation.delegate = self;
	transformAnimation.removedOnCompletion = NO;

	[transformAnimation setValue:initialView forKey:@"initialView"];
	[transformAnimation setValue:finalView forKey:@"finalView"];
	
	[transformAnimation setValue:@(xRatio) forKey:@"xRatio"];
	[transformAnimation setValue:@(yRatio) forKey:@"yRatio"];
	[transformAnimation setValue:@(invertRotation) forKey:@"invertRotation"];
	[transformAnimation setValue:[NSValue valueWithRect:finalFrame] forKey:@"finalFrame"];
	
	[initialLayer addAnimation:transformAnimation forKey:@"transform"];
	
	CABasicAnimation * translateAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
	translateAnimation.duration = FLIP_DURATION;
	translateAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	
	CATransform3D finalTranslate = CATransform3DMakeTranslation(NSMidX(finalFrame) - NSMidX(initialFrame), NSMidY(finalFrame) - NSMidY(initialFrame), 0.0);
	
	translateAnimation.toValue = [NSValue valueWithCATransform3D:finalTranslate];
	translateAnimation.fillMode = kCAFillModeForwards;
	translateAnimation.removedOnCompletion = NO;
	
	[parentLayer addAnimation:translateAnimation forKey:@"translate"];
	
	[CATransaction commit];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
	if(_step == 0) {
		_step++;
		[self continueFlipAnimationFromAnimation:anim];
	}
	else {
		[self endFlipAnimationFromAnimation:anim];
	}
}

- (void)continueFlipAnimationFromAnimation:(CAAnimation*)anim
{
	[CATransaction begin];
	[CATransaction setValue:@YES forKey:kCATransactionDisableActions];
		
	NSView * initialView = [anim valueForKey:@"initialView"];
	NSView * finalView = [anim valueForKey:@"finalView"];
	BOOL invertRotation = [[anim valueForKey:@"invertRotation"] boolValue];

	CALayer * finalLayer = [finalView layer];
	
	[initialView setHidden:YES];
	[finalView setHidden:NO];

	CGFloat xRatio = [[anim valueForKey:@"xRatio"] doubleValue];
	CGFloat yRatio = [[anim valueForKey:@"yRatio"] doubleValue];
		
	CABasicAnimation * transformAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
	transformAnimation.duration = anim.duration;
	transformAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	
	CGFloat angle = invertRotation ? ROTATION_ANGLE : -ROTATION_ANGLE;
	CATransform3D initialTransform = CATransform3DMakeRotation(angle, 1.0, 0.0, 0.0);
	
	initialTransform = CATransform3DScale(initialTransform, 0.5 + xRatio/2.0, 0.5 + yRatio/2.0, 1.0);
	
	CATransform3D finalTransform = CATransform3DMakeRotation(0.0, 1.0, 0.0, 0.0);
	
	transformAnimation.fromValue = [NSValue valueWithCATransform3D:initialTransform];
	transformAnimation.toValue = [NSValue valueWithCATransform3D:finalTransform];
	transformAnimation.fillMode = kCAFillModeForwards;

	transformAnimation.removedOnCompletion = YES;

	transformAnimation.delegate = self;
	
	[transformAnimation setValue:initialView forKey:@"initialView"];
	[transformAnimation setValue:finalView forKey:@"finalView"];
	[transformAnimation setValue:[anim valueForKey:@"finalFrame"] forKey:@"finalFrame"];

	
	[finalLayer addAnimation:transformAnimation forKey:@"transform"];
	
	[CATransaction commit];
}

- (void)endFlipAnimationFromAnimation:(CAAnimation*)anim
{
	NSView * initialView = [anim valueForKey:@"initialView"];
	NSView * finalView = [anim valueForKey:@"finalView"];
	NSView * parentView = [initialView superview];
	NSView * rootView = [parentView superview];
	NSRect finalFrame = [[anim valueForKey:@"finalFrame"] rectValue];
	
	NSRect frame = [parentView convertRect:[initialView frame] toView:rootView];
	[initialView removeFromSuperview];
	[initialView setFrame:frame];
	[rootView addSubview:initialView];
	
	[finalView removeFromSuperview];
	[finalView setFrame:finalFrame];
	[rootView addSubview:finalView];
	
	[parentView removeFromSuperview];
	
	if(_delegate && [_delegate respondsToSelector:@selector(animationDidComplete)]) {
		[_delegate animationDidComplete];
	}
	
}

@end
