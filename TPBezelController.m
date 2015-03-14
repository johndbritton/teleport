//
//  TPBezelController.m
//  teleport
//
//  Created by JuL on 27/07/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import "TPBezelController.h"

#import "TPBezelWindow.h"
#import "TPBezelView.h"

#import "TPTransfersManager.h"
#import "TPTransfer.h"

#import "TPRemoteHost.h"

#define TEXT_DURATION 5.0

static TPBezelController * _defaultController = nil;

@implementation TPBezelController

+ (TPBezelController*)defaultController
{
	if(_defaultController == nil)
		_defaultController = [[TPBezelController alloc] init];
	return _defaultController;
}

- (instancetype) init
{
	self = [super init];
	
	_bezelWindow = nil;
	_bezelView = nil;
	_textTimer = nil;
	
	return self;
}


- (void)showBezelWithControlledHost:(TPRemoteHost*)host
{
	NSRect localFrame = [[host localScreen] frame];
	
	if(_bezelWindow == nil) {
		_bezelWindow = [[TPBezelWindow alloc] initWithContentRect:localFrame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];

		_bezelView = [[TPBezelView alloc] init];
		[_bezelWindow setContentView:_bezelView];
	}
	
	[_bezelView setRemoteHost:host];
	[_bezelView setShowProgress:NO];
	[_bezelWindow orderFront:nil];
	[_bezelWindow orderFrontRegardless];
	
	if([_bezelWindow respondsToSelector:@selector(setCollectionBehavior:)]) {
		[_bezelWindow setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorStationary];
	}
}

- (void)hideBezel
{
	[_bezelWindow orderOut:self];
	if(_textTimer != nil) {
		[_textTimer invalidate];
		_textTimer = nil;
	}
	[_bezelView setText:nil];
}

- (void)showText:(NSString*)text withDuration:(NSTimeInterval)duration
{
	[_bezelView setText:text];
	if(_textTimer != nil)
		[_textTimer invalidate];
	_textTimer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(_removeText:) userInfo:nil repeats:NO];
}

- (void)_removeText:(NSTimer*)timer
{
	[_bezelView setText:nil];
	_textTimer = nil;
}


#pragma mark -
#pragma mark TPTransfersManager delegate

- (void)transfersManager:(TPTransfersManager*)transfersManager beginNewTransfer:(TPTransfer*)transfer
{
	if(![transfer isIncoming]) {
		[_bezelView setShowProgress:YES];
		[_bezelView setProgress:0.0];
	}
}

- (void)transfersManager:(TPTransfersManager*)transfersManager transfer:(TPTransfer*)transfer didProgress:(float)progress
{
	if(![transfer isIncoming]) {
		[_bezelView setShowProgress:YES];
		[_bezelView setProgress:progress];
	}
}

- (void)transfersManager:(TPTransfersManager*)transfersManager completeTransfer:(TPTransfer*)transfer
{
	if(![transfer isIncoming]) {
		[_bezelView setShowProgress:NO];
		NSString * message = [transfer completionMessage];
		if(message != nil)
			[self showText:message withDuration:TEXT_DURATION];
	}
}

- (void)transfersManager:(TPTransfersManager*)transfersManager cancelTransfer:(TPTransfer*)transfer
{
	if(![transfer isIncoming]) {
		[_bezelView setShowProgress:NO];
		NSString * message = [transfer errorMessage];
		if(message != nil)
			[self showText:message withDuration:TEXT_DURATION];
	}
}

@end
