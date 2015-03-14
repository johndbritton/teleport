//
//  TPLayoutRemoteHost.h
//  PrefsPanel
//
//  Created by JuL on Mon Dec 08 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TPLayoutHostView.h"
#import "TPHostSnapping.h"

@class TPRemoteHost;

@interface TPLayoutRemoteScreenView : TPLayoutScreenView
{
	NSTrackingArea * _trackingArea;
	NSButton * _optionsButton;
	NSButton * _unpairButton;
	
	unsigned _cachedBackgroundHash;
	NSImage * _cachedBackgroundImage;
}

- (void)_setupButtons;
- (void)_updateUnpairButton;
- (void)_updateOptionsButton;
@property (nonatomic, readonly) BOOL _canShowOptionsButton;

@property (nonatomic, getter=isSharedScreen, readonly) BOOL sharedScreen;

@end

@interface TPLayoutRemoteHostView : TPLayoutHostView
{
	NSString * _remoteHostIdentifier;
	
	BOOL _dragging;
	BOOL _snapped;
	
	NSPoint _deltaDrag;

	NSPoint _snappedPosition;
	unsigned _snappedScreenIndex;
	unsigned _draggingScreenIndex;
}

@property (nonatomic) unsigned int draggingScreenIndex;

- (NSPoint)adjustedScreenPositionFromPosition:(NSPoint)position localScreenIndex:(unsigned)screenIndex side:(TPSide)side;
- (void)pairToScreenIndex:(int)screenIndex atPosition:(NSPoint)position ofSide:(TPSide)side;
- (void)unpair;
@property (nonatomic, readonly) BOOL canUnpair;

- (void)update;

#if 0
- (NSRect)rectWithSnapping:(BOOL)snapping side:(TPSide*)side;
- (NSRect)drawRectWithSnapping:(BOOL)snapping;
- (NSRect)unpairRectFromDrawRect:(NSRect)drawRect;

- (void)moveToPoint:(NSPoint)point;

- (NSPoint)snappedPosition;
- (unsigned)snappedScreenIndex;

- (void)startDraggingAtPoint:(NSPoint)dragPoint;
- (void)stopDragging;
- (BOOL)isDragging;

- (void)snapToScreenIndex:(int)screenIndex atPosition:(NSPoint)position ofSide:(TPSide)side;
- (void)unsnap;
- (BOOL)isSnapped;

- (void)pair;
- (void)unpair;
- (BOOL)canUnpair;
#endif
@end
