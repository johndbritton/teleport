//
//  TPOptionsController.m
//  teleport
//
//  Created by Julien Robert on 02/04/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "TPOptionsController.h"
#import "TPLayoutView.h"
#import "TPLayoutRemoteHostView.h"
#import "TPAnimationManager.h"
#import "TPRemoteHost.h"
#import "PTKeyCombo.h"
#import "TPKeyComboView.h"

static TPOptionsController * _controller = nil;

@interface TPLayoutOptionsProxy : NSObject
{
	TPOptionsController * _optionsController;
	NSMutableSet * _allObservedKeys;
}

- (instancetype) initWithOptionsController:(TPOptionsController*)optionsController NS_DESIGNATED_INITIALIZER;

- (void)willChangeAllObservedKeys;
- (void)didChangeAllObservedKeys;

@end

@implementation TPLayoutOptionsProxy

- (instancetype) initWithOptionsController:(TPOptionsController*)optionsController
{
	self = [super init];
	
	_optionsController = optionsController;
	
	return self;
}


- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
	[super addObserver:observer forKeyPath:keyPath options:options context:context];
	
	if(_allObservedKeys == nil) {
		_allObservedKeys = [[NSMutableSet alloc] init];
	}
	
	[_allObservedKeys addObject:keyPath];
}

- (id)valueForKey:(NSString*)key
{
	return [[_optionsController host] optionForKey:key];
}

- (void)setValue:(id)value forKey:(NSString*)key
{
	[self willChangeValueForKey:key];
	[_optionsController willChangeValueForKey:@"hasCustomOptions"];
	[[[_optionsController host] options] setValue:value forKey:key];
	[_optionsController didChangeValueForKey:@"hasCustomOptions"];
	[self didChangeValueForKey:key];
}

- (void)willChangeAllObservedKeys
{
	for(NSString * key in _allObservedKeys) {
		[self willChangeValueForKey:key];
	}
}

- (void)didChangeAllObservedKeys
{
	for(NSString * key in _allObservedKeys) {
		[self didChangeValueForKey:key];
	}
}

@end


@implementation TPOptionsController

+ (TPOptionsController*)controller
{
	if(_controller == nil)
		_controller = [[TPOptionsController alloc] init];
	return _controller;
}

- (instancetype) init
{
	self = [super init];
	
	_controller = self;
	
	return self;
}

- (void)awakeFromNib
{
	[keyComboView bind:@"keyCombo" toObject:self withKeyPath:@"host.keyCombo" options:nil];
	[keyComboView setDelegate:(id)self];
	
	//NSResponder * nextResponder = [hostOptionsView nextResponder];
	[hostOptionsView setNextResponder:self];
	//[self setNextResponder:nextResponder];
}

- (void)showOptionsForHost:(TPRemoteHost*)host sharedScreenIndex:(unsigned)screenIndex fromRect:(NSRect)blabla
{
	[self willChangeValueForKey:@"hostOptions"];
	
	_host = host;
	_optionsProxy = [[TPLayoutOptionsProxy alloc] initWithOptionsController:self];
	
	[self didChangeValueForKey:@"hostOptions"];
	
	[titleTextField setStringValue:[NSString stringWithFormat:@"Options for %@", [host computerName]]];
		
	TPLayoutRemoteHostView * remoteHostView = [layoutView remoteHostViewForHost:host];
	_currentScreenView = [remoteHostView screenViewAtIndex:screenIndex];
	_currentScreenFrame = [_currentScreenView frame];
	NSRect frame = [_currentScreenView convertRect:[_currentScreenView bounds] toView:layoutView];

	[_currentScreenView removeFromSuperview];
	[_currentScreenView setFrame:frame];
	[layoutView addSubview:_currentScreenView];
	
	NSRect optionsFrame = [TPAnimationManager rect:[hostOptionsView bounds] centeredAtPoint:NSMakePoint(NSMidX(frame), NSMidY(frame))];
	optionsFrame = [TPAnimationManager rect:optionsFrame snappedInsideRect:[layoutView bounds] margin:16.0];
	optionsFrame.origin.x = round(optionsFrame.origin.x);
	optionsFrame.origin.y = round(optionsFrame.origin.y);

	[hostOptionsView setFrame:optionsFrame];
	[hostOptionsView setHidden:YES];
	[layoutView addSubview:hostOptionsView];
	
	[TPAnimationManager flipAnimationFromView:_currentScreenView toView:hostOptionsView invertRotation:NO delegate:self];
}

- (IBAction)restoreToDefaults:(id)sender
{
	[self willChangeValueForKey:@"hasCustomOptions"];
	[_optionsProxy willChangeAllObservedKeys];
	[_host resetCustomOptions];
	[_optionsProxy didChangeAllObservedKeys];
	[self didChangeValueForKey:@"hasCustomOptions"];
}

- (IBAction)useAsDefaults:(id)sender
{
	[self willChangeValueForKey:@"hasCustomOptions"];
	[_host makeDefaultOptions];
	[self didChangeValueForKey:@"hasCustomOptions"];
}

- (IBAction)closeOptions:(id)sender
{
	[TPAnimationManager flipAnimationFromView:hostOptionsView toView:_currentScreenView invertRotation:YES delegate:self];
}

- (void)keyComboDidChange:(PTKeyCombo*)keyCombo
{
	[_host setKeyCombo:keyCombo];
}

- (void)flagsChanged:(NSEvent *)theEvent
{
	if(([theEvent modifierFlags] & NSAlternateKeyMask) != 0) {
		[restoreSaveDefaultsButton setTitle:NSLocalizedStringFromTableInBundle(@"Restore to Defaults", nil, [NSBundle bundleForClass:[self class]], @"Button title")];
		[restoreSaveDefaultsButton setAction:@selector(restoreToDefaults:)];
	}
	else {
		[restoreSaveDefaultsButton setTitle:NSLocalizedStringFromTableInBundle(@"Use as Defaults", nil, [NSBundle bundleForClass:[self class]], @"Button title")];
		[restoreSaveDefaultsButton setAction:@selector(useAsDefaults:)];
	}
}

- (void)keyDown:(NSEvent*)event
{
	unsigned short keyCode = [event keyCode];
	if(keyCode == 53) {
		[self closeOptions:nil];
	}
}

- (void)animationDidComplete
{
	if([hostOptionsView isHidden]) {
		[self willChangeValueForKey:@"hostOptions"];
		
		_host = nil;
		_optionsProxy = nil;
		
		[self didChangeValueForKey:@"hostOptions"];
		
		[layoutView updateLayout];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:TPHostDidUpdateNotification object:_host userInfo:nil];
		
		TPLayoutHostView * hostView = [_currentScreenView hostView];
		[_currentScreenView removeFromSuperview];
		[_currentScreenView setFrame:_currentScreenFrame];
		[hostView addSubview:_currentScreenView];
		
		[layoutView updateLayout];

		_currentScreenView = nil;
	}
	else {
		[[hostOptionsView window] makeFirstResponder:hostOptionsView];
		[hostOptionsView setNextResponder:self];
	}
}

- (TPRemoteHost*)host
{
	return _host;
}

- (id)hostOptions
{
	return _optionsProxy;
}

+ (NSSet*)keyPathsForValuesAffectingHasCustomOptions
{
	return [NSSet setWithObject:@"hostOptions"];
}

- (BOOL)hasCustomOptions
{
	return [_host hasCustomOptions];
}

@end
