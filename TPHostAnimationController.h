//
//  TPHostAnimationController.h
//  teleport
//
//  Created by Julien Robert on 23/02/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TPHostSnapping.h"
#import "TPRemoteHost.h"

@class TPEffectsWindow;

@interface TPHostPlacementIndicator : NSObject
{
	TPEffectsWindow * _window;
	CALayer * _layer;
	TPRemoteHost * _remoteHost;
	NSRect _hostRect;
	TPSide _currentSide;
	unsigned _currentScreenIndex;
}

- (instancetype) initWithHost:(TPRemoteHost*)remoteHost NS_DESIGNATED_INITIALIZER;
- (void)setHostRect:(NSRect)hostRect localScreenIndex:(unsigned)localScreenIndex;

- (void)show;
- (void)close;

@end

@interface TPHostAnimationController : NSObject

+ (TPHostAnimationController*)controller;

- (void)showFireAnimationForHost:(TPRemoteHost*)host atPoint:(NSPoint)point onScreen:(NSScreen*)screen side:(TPSide)side;
- (void)showAppearanceAnimationForHost:(TPRemoteHost*)host;

@end
