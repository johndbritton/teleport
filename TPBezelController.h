//
//  TPBezelController.h
//  teleport
//
//  Created by JuL on 27/07/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TPBezelWindow, TPBezelView;
@class TPRemoteHost;

@interface TPBezelController : NSObject
{
	TPBezelWindow * _bezelWindow;
	TPBezelView * _bezelView;
	NSTimer * _textTimer;
}

+ (TPBezelController*)defaultController;

- (void)showBezelWithControlledHost:(TPRemoteHost*)host;
- (void)hideBezel;

- (void)showText:(NSString*)text withDuration:(NSTimeInterval)duration;

@end
