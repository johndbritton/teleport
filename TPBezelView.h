//
//  TPBezelView.h
//  Teleport
//
//  Created by JuL on Fri Dec 12 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <AppKit/AppKit.h>

@class TPRemoteHost;

@interface TPBezelView : NSView
{
	TPRemoteHost * _remoteHost;
	NSString * _text;
	BOOL _showProgress;
	float _progress;
	NSTimer * _indeterminateTimer;
	int _indeterminateDelta;
}

- (void)setRemoteHost:(TPRemoteHost*)remoteHost;
- (void)setText:(NSString*)text;
- (void)setShowProgress:(BOOL)showProgress;
- (void)setProgress:(float)progress;

@end
