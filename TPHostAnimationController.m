//
//  TPHostAnimationController.m
//  teleport
//
//  Created by Julien Robert on 23/02/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "TPHostAnimationController.h"

#import <QuartzCore/QuartzCore.h>

#import "TPLocalHost.h"

@interface NSObject (TeleportLayerSupport)

- (void)setWantsLayer:(BOOL)flag;
@property (nonatomic, readonly, strong) id layer;

- (void)addSublayer:(id)layer;
- (void)setContents:(id)contents;
- (void)setFrame:(CGRect)frame;
- (void)setBounds:(CGRect)bounds;
- (void)setPosition:(CGPoint)position;
- (void)setOpacity:(float)opacity;
- (void)setAffineTransform:(CGAffineTransform)m;
- (void)addAnimation:(id)anim forKey:(NSString *)key;

- (void)begin;
- (void)commit;

- (id)animationWithKeyPath:(NSString *)path;
- (void)setToValue:(id)value;
- (void)setRemovedOnCompletion:(BOOL)flag;
- (void)setDuration:(CFTimeInterval)duration;
- (void)setFillMode:(NSString*)fillMode;

@end

@interface TPEffectsWindow : NSWindow

- (instancetype) initWithFrame:(NSRect)frame NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, strong) CALayer *effectsLayer;

@end

@implementation TPEffectsWindow

- (instancetype) initWithFrame:(NSRect)frame
{
	self = [super initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	
	[self setOpaque:NO];
	[self setIgnoresMouseEvents:YES];
	[self setLevel:kCGDraggingWindowLevel-1];
	[self setReleasedWhenClosed:NO];
	[self setBackgroundColor:[NSColor clearColor]];
	
	NSView * view = [self contentView];
	[view setWantsLayer:YES];
	
	if ([view respondsToSelector:@selector(setLayerUsesCoreImageFilters:)]) {
		[view setLayerUsesCoreImageFilters:YES];
	}
	
	return self;
}

- (void)close
{
	[[self contentView] setWantsLayer:NO];
	[super close];
}

- (CALayer*)effectsLayer
{
	return [[self contentView] layer];
}

@end

static TPHostAnimationController* _controller = nil;

@interface TPHostAnimationController ()

@property (nonatomic, strong) NSMutableSet *effectWindows;

@end

@implementation TPHostAnimationController

+ (TPHostAnimationController*)controller
{
	if(_controller == nil) {
		_controller = [[TPHostAnimationController alloc] init];
	}
	
	return _controller;
}

- (instancetype)init
{
	self = [super init];
	
	self.effectWindows = [[NSMutableSet alloc] init];
	
	return self;
}

#pragma mark -
#pragma mark Fire

#define FIRE_HALO_COUNT 4
#define FIRE_DURATION 0.8
- (void)showFireAnimationForHost:(TPRemoteHost*)host atPoint:(NSPoint)point onScreen:(NSScreen*)screen side:(TPSide)side
{
	static CGImageRef _haloImageRef = NULL;
	
	if(_haloImageRef == NULL) {
		NSString * imagePath = [[NSBundle mainBundle] pathForResource:@"halo" ofType:@"png"];
		CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:imagePath], NULL);
		if(imageSource != NULL) {
			_haloImageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
			CFRelease(imageSource);
		}		
	}
	
	TPEffectsWindow * effectWindow = [[TPEffectsWindow alloc] initWithFrame:[screen frame]];
	[_effectWindows addObject:effectWindow];
	id rootLayer = [effectWindow effectsLayer];
	
	CGRect imageBounds = CGRectMake(0.0, 0.0, CGImageGetWidth(_haloImageRef), CGImageGetHeight(_haloImageRef));
	id layers[FIRE_HALO_COUNT];
	
	id layerClass = [CALayer class];
	id transactionClass = [CATransaction class];
	
	float xDirection = 0.0;
	float yDirection = 0.0;
	CGAffineTransform baseTransform = CGAffineTransformIdentity;
	point = [effectWindow convertScreenToBase:point];
	
	if(side & TPLeftSide) {
		if(side & TPTopSide) {
			baseTransform = CGAffineTransformMakeRotation(M_PI/4.0);
			xDirection = +1/sqrtf(2);
		}
		else if(side & TPBottomSide) {
			baseTransform = CGAffineTransformMakeRotation(-M_PI/4.0);
			xDirection = +1/sqrtf(2);
		}
		else {
			baseTransform = CGAffineTransformMakeRotation(M_PI/2.0);
			xDirection = +1;
		}
	}
	
	if(side & TPRightSide) {
		if(side & TPTopSide) {
			baseTransform = CGAffineTransformMakeRotation(-M_PI/4.0);
			xDirection = -1/sqrtf(2);
		}
		else if(side & TPBottomSide) {
			baseTransform = CGAffineTransformMakeRotation(M_PI/4.0);
			xDirection = -1/sqrtf(2);
		}
		else {
			baseTransform = CGAffineTransformMakeRotation(M_PI/2.0);
			xDirection = -1;
		}
	}
	
	if(side & TPTopSide) {
		if(side & (TPRightSide|TPLeftSide)) {
			yDirection = -1/sqrtf(2);
		}
		else {
			yDirection = -1;
		}
	}
	
	if(side & TPBottomSide) {
		if(side & (TPRightSide|TPLeftSide)) {
			yDirection = +1/sqrtf(2);
		}
		else {
			yDirection = +1;
		}
	}
	
	[transactionClass begin];
	
	int i;
	for(i=0; i<FIRE_HALO_COUNT; i++) {
		id layer = [layerClass layer];
		
		[(NSObject*)layer setBounds:imageBounds];
		
		float scale = 0.2;
		float delta = i*4;
		
		[layer setPosition:CGPointMake(point.x - xDirection*delta, point.y - yDirection*delta)];
		[layer setContents:(__bridge id)_haloImageRef];
		[layer setOpacity:1.5];
		[layer setAffineTransform:CGAffineTransformScale(baseTransform, scale, scale)];
		
		[rootLayer addSublayer:layer];
		
		layers[i] = layer;
	}
	
	[transactionClass commit];
	
	[effectWindow orderFront:nil];
	
	[transactionClass begin];
	[transactionClass setValue:@(FIRE_DURATION) forKey:@"animationDuration"];
	
	for(i=0; i<FIRE_HALO_COUNT; i++) {
		id layer = layers[i];
		
		float factor = powf(i, 1.5);
		float scale = 0.2 + 0.06*factor;
		float delta = 5 + 8*factor;
		
		[layer setOpacity:-0.2*i/(float)FIRE_HALO_COUNT];
		[layer setAffineTransform:CGAffineTransformScale(baseTransform, scale, scale)];
		[layer setPosition:CGPointMake(point.x + xDirection*delta, point.y + yDirection*delta)];
	}
	
	[transactionClass commit];
	
	[self performSelector:@selector(_doneFireAnimation:) withObject:effectWindow afterDelay:FIRE_DURATION];
}

- (void)_doneFireAnimation:(NSWindow*)effectWindow
{
	[effectWindow close];
	
	// This addresses https://github.com/abyssoft/teleport/issues/10
	[_effectWindows removeObject:effectWindow];
}


#pragma mark -
#pragma mark Appearance

#define APPEARANCE_BORDER_SIZE 8.0
#define APPEARANCE_BLUR_RADIUS 2.0
#define APPEARANCE_IN_DURATION 0.5
#define APPEARANCE_MIDDLE_DURATION 0.75
#define APPEARANCE_MIDDLE_OPACITY 0.25
#define APPEARANCE_OUT_DURATION 0.5
- (void)showAppearanceAnimationForHost:(TPRemoteHost*)host
{
	NSRect representedRect = [host adjustedHostRect];
	NSRect parentRect = [[host localScreen] frame];
	TPSide side;
	TPGluedRect(NULL, &side, parentRect, representedRect, TPUndefSide);
	
	NSRect windowFrame = NSIntersectionRect(parentRect, NSInsetRect(representedRect, -APPEARANCE_BORDER_SIZE, -APPEARANCE_BORDER_SIZE));
	BOOL horizontal = (side == TPTopSide) || (side == TPBottomSide);
	windowFrame = NSInsetRect(windowFrame, horizontal ? -APPEARANCE_BLUR_RADIUS : 0.0, horizontal ? 0.0 : -APPEARANCE_BLUR_RADIUS);
	
	TPEffectsWindow * effectWindow = [[TPEffectsWindow alloc] initWithFrame:windowFrame];	

	[effectWindow orderFront:nil];

	CALayer * rootLayer = [effectWindow effectsLayer];
	//rootLayer.backgroundColor = (CGColorRef)[(id)CGColorCreateGenericRGB(0.0, 1.0, 0.0, 1.0) autorelease];

	CALayer * layer = [CALayer layer];
	CGColorRef color = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
	layer.backgroundColor = color;
	CFRelease(color);
	
	CGRect frame = CGRectInset(rootLayer.bounds, horizontal ? APPEARANCE_BLUR_RADIUS : 0.0, horizontal ? 0.0 : APPEARANCE_BLUR_RADIUS);
	
	switch(side) {
		case TPTopSide:
			frame.origin.y += APPEARANCE_BLUR_RADIUS;
			break;
		case TPBottomSide:
			frame.origin.y -= APPEARANCE_BLUR_RADIUS;
			break;
		case TPLeftSide:
			frame.origin.x -= APPEARANCE_BLUR_RADIUS;
			break;
		case TPRightSide:
			frame.origin.x += APPEARANCE_BLUR_RADIUS;
			break;
		default:
			break;
	}
	
	layer.frame = frame;
	[rootLayer addSublayer:layer];
	
	CIFilter * filter = [CIFilter filterWithName:@"CIGaussianBlur"];
	[filter setValue:[NSNumber numberWithFloat:APPEARANCE_BLUR_RADIUS] forKey:kCIInputRadiusKey];
	layer.filters = @[filter];

	CATransform3D appearTransform;
	switch(side) {
		case TPTopSide:
			appearTransform = CATransform3DMakeTranslation(0.0, APPEARANCE_BORDER_SIZE, 0.0);
			break;
		case TPBottomSide:
			appearTransform = CATransform3DMakeTranslation(0.0, -APPEARANCE_BORDER_SIZE, 0.0);
			break;
		case TPLeftSide:
			appearTransform = CATransform3DMakeTranslation(-APPEARANCE_BORDER_SIZE, 0.0, 0.0);
			break;
		case TPRightSide:
			appearTransform = CATransform3DMakeTranslation(APPEARANCE_BORDER_SIZE, 0.0, 0.0);
			break;
		default:
			appearTransform = CATransform3DIdentity;
	}
	
	CABasicAnimation * appearAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
	appearAnimation.fromValue = [NSValue valueWithCATransform3D:appearTransform];
	appearAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	appearAnimation.duration = APPEARANCE_IN_DURATION;
	[layer addAnimation:appearAnimation forKey:@"appear"];
	
	CAKeyframeAnimation * middleAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
	middleAnimation.beginTime = CACurrentMediaTime() + APPEARANCE_IN_DURATION;
	middleAnimation.values = @[@1.0f,
							  [NSNumber numberWithFloat:APPEARANCE_MIDDLE_OPACITY],
							  @1.0f,
							  [NSNumber numberWithFloat:APPEARANCE_MIDDLE_OPACITY],
							  @1.0f];
	middleAnimation.fillMode = kCAFillModeForwards;
	middleAnimation.removedOnCompletion = NO;
	middleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	middleAnimation.duration = APPEARANCE_MIDDLE_DURATION;
	[layer addAnimation:middleAnimation forKey:@"middle"];
	
	CABasicAnimation * disappearAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
	disappearAnimation.beginTime = CACurrentMediaTime() + APPEARANCE_IN_DURATION + APPEARANCE_MIDDLE_DURATION;
	disappearAnimation.toValue = [NSValue valueWithCATransform3D:appearTransform];
	disappearAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	disappearAnimation.duration = APPEARANCE_OUT_DURATION;
	disappearAnimation.fillMode = kCAFillModeForwards;
	disappearAnimation.removedOnCompletion = NO;
	[layer addAnimation:disappearAnimation forKey:@"disappear"];
	
	[self performSelector:@selector(_doneAppearanceAnimation:) withObject:effectWindow afterDelay:APPEARANCE_IN_DURATION + APPEARANCE_MIDDLE_DURATION + APPEARANCE_OUT_DURATION];
}

- (void)_doneAppearanceAnimation:(NSWindow*)effectWindow
{
	[effectWindow close];
	[_effectWindows removeObject:effectWindow];
}

@end

@interface TPHostPlacementIndicator (Internal)

- (NSRect)_windowFrameWithSide:(TPSide*)outSide;
- (CGRect)_layerFrameWithSide:(TPSide)side;
- (void)_updateWindowLocation;

@end

@implementation TPHostPlacementIndicator

- (instancetype) initWithHost:(TPRemoteHost*)remoteHost
{
	self = [super init];
	
	_remoteHost = remoteHost;
	
	return self;
}

- (void)dealloc
{
	[_window close];
}

- (void)setHostRect:(NSRect)hostRect localScreenIndex:(unsigned)localScreenIndex
{
	_hostRect = hostRect;
	_currentScreenIndex = localScreenIndex;
	
	if(_window != nil) {
		[self _updateWindowLocation];
	}
}

- (void)show
{
	NSRect windowFrame = [self _windowFrameWithSide:&_currentSide];
	
	_window = [[TPEffectsWindow alloc] initWithFrame:windowFrame];
	[_window orderFront:nil];
	
	CALayer * rootLayer = [_window effectsLayer];
	//rootLayer.backgroundColor = (CGColorRef)[(id)CGColorCreateGenericRGB(0.0, 1.0, 0.0, 1.0) autorelease];
	
	_layer = [CALayer layer];
	CGColorRef color = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
	_layer.backgroundColor = color;
	CFRelease(color);
	
	_layer.frame = [self _layerFrameWithSide:_currentSide];
	_layer.autoresizingMask = kCALayerHeightSizable|kCALayerWidthSizable;
	[rootLayer addSublayer:_layer];
	
	CIFilter * filter = [CIFilter filterWithName:@"CIGaussianBlur"];
	[filter setValue:[NSNumber numberWithFloat:APPEARANCE_BLUR_RADIUS] forKey:kCIInputRadiusKey];
	_layer.filters = @[filter];
}

- (void)close
{
	[_window setAlphaValue:0.0];
	[_window close];
	_window = nil;
}

- (NSRect)_windowFrameWithSide:(TPSide*)outSide
{
	NSRect representedRect = _hostRect;
	NSRect parentRect = [[[TPLocalHost localHost] screenAtIndex:_currentScreenIndex] frame];
	TPSide side;
	TPGluedRect(NULL, &side, parentRect, representedRect, TPUndefSide);
	
	NSRect windowFrame = NSIntersectionRect(parentRect, NSInsetRect(representedRect, -APPEARANCE_BORDER_SIZE, -APPEARANCE_BORDER_SIZE));
	BOOL horizontal = (side == TPTopSide) || (side == TPBottomSide);
	windowFrame = NSInsetRect(windowFrame, horizontal ? -APPEARANCE_BLUR_RADIUS : 0.0, horizontal ? 0.0 : -APPEARANCE_BLUR_RADIUS);
	
	if(outSide != NULL) {
		*outSide = side;
	}
	windowFrame.size.height = MAX(NSHeight(windowFrame), 4.0);
	windowFrame.size.width = MAX(NSWidth(windowFrame), 4.0);

	return windowFrame;
}

- (CGRect)_layerFrameWithSide:(TPSide)side
{
	NSView * effectView = [_window contentView];
	CALayer * rootLayer = [effectView layer];
	BOOL horizontal = (side == TPTopSide) || (side == TPBottomSide);
	CGRect frame = CGRectInset(rootLayer.bounds, horizontal ? APPEARANCE_BLUR_RADIUS : 0.0, horizontal ? 0.0 : APPEARANCE_BLUR_RADIUS);
	
	switch(side) {
		case TPTopSide:
			frame.origin.y += APPEARANCE_BLUR_RADIUS;
			break;
		case TPBottomSide:
			frame.origin.y -= APPEARANCE_BLUR_RADIUS;
			break;
		case TPLeftSide:
			frame.origin.x -= APPEARANCE_BLUR_RADIUS;
			break;
		case TPRightSide:
			frame.origin.x += APPEARANCE_BLUR_RADIUS;
			break;
		default:
			break;
	}

	return frame;
}

- (void)_updateWindowLocation
{
	TPSide side;
	NSRect windowFrame = [self _windowFrameWithSide:&side];
	
	if(side != _currentSide) {
		[CATransaction begin];
		[CATransaction setValue:@YES forKey:kCATransactionDisableActions];
		_layer.frame = [self _layerFrameWithSide:side];
		[CATransaction commit];
		
		_currentSide = side;
	}

	[_window setFrame:windowFrame display:YES animate:NO];
}

- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
	return (id<CAAction>)[NSNull null];
}

@end
