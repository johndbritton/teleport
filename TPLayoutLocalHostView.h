//
//  TPLayoutLocalHost.h
//  teleport
//
//  Created by JuL on Fri Feb 27 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TPLayoutHostView.h"
#import "TPHostSnapping.h"

@class TPLocalHost;

@interface TPLayoutLocalHostView : TPLayoutHostView
{
	NSScreen * _insideScreen;
}

- (unsigned)nearestScreenIndexForFrame:(NSRect)frame distance:(float*)distance position:(NSPoint*)hostPosition side:(TPSide*)side;

#if 0
- (NSRect)rectForScreen:(NSScreen*)screen;
- (NSRect)drawRectForScreen:(NSScreen*)screen;
- (NSRect)shareScreenRectFromDrawRect:(NSRect)drawRect;
- (NSRect)totalRect;
- (NSSize)totalSize;

- (NSScreen*)screenAtPoint:(NSPoint)point;
#endif
@end
