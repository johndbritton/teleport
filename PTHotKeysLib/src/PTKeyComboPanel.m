//
//  PTKeyComboPanel.m
//  Protein
//
//  Created by Quentin Carnicelli on Sun Aug 03 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import "PTKeyComboPanel.h"

#import "PTHotKey.h"
#import "PTKeyCombo.h"
#import "PTKeyBroadcaster.h"
#import "PTHotKeyCenter.h"

#if __PROTEIN__
#import "PTNSObjectAdditions.h"
#endif

@implementation PTKeyComboPanel

static PTKeyComboPanel* _sharedKeyComboPanel = nil;

+ (PTKeyComboPanel*)sharedPanel
{
	if( _sharedKeyComboPanel == nil )
	{
		_sharedKeyComboPanel = [[self alloc] init];
	
		#if __PROTEIN__
			[_sharedKeyComboPanel releaseOnTerminate];
		#endif
	}

	return _sharedKeyComboPanel;
}

- (instancetype)init
{
	return [self initWithWindowNibName: @"PTKeyComboPanel"];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];

}

- (void)windowDidLoad
{
	[super windowDidLoad];

	mTitleFormat = [mTitleField stringValue];

	[[NSNotificationCenter defaultCenter]
		addObserver: self
		selector: @selector( noteKeyBroadcast: )
		name: PTKeyBroadcasterKeyEvent
		object: mKeyBcaster];
}

- (void)_refreshContents
{
	if( mComboField )
		[mComboField setStringValue: [mKeyCombo description]];

	if( mTitleField )
		[mTitleField setStringValue: [NSString stringWithFormat: mTitleFormat, mKeyName]];
}

#pragma mark -

- (int)runModal
{
	int resultCode;

	(void)[self window]; //Force us to load

	[self _refreshContents];
	[[self window] center];
	[self showWindow: self];
	resultCode = [[NSApplication sharedApplication] runModalForWindow: [self window]];
	[self close];

	return resultCode;
}

- (void)runModalForHotKey: (PTHotKey*)hotKey
{
	int resultCode;

	[self setKeyBindingName: [hotKey name]];
	[self setKeyCombo: [hotKey keyCombo]];

	resultCode = [self runModal];
	
	if( resultCode == NSOKButton )
	{
		[hotKey setKeyCombo: [self keyCombo]];
		[[PTHotKeyCenter sharedCenter] registerHotKey: hotKey];
	}
}

#pragma mark -

- (void)_sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	id delegate = (__bridge id)contextInfo;
	
	[sheet orderOut: nil];
	[self close];
	
	if( delegate )
	{
		NSNumber* returnObj = @(returnCode);
		[delegate performSelector: @selector( hotKeySheetDidEndWithReturnCode: ) withObject: returnObj];
	}
}

- (void)runSheeetForModalWindow: (NSWindow*)wind target: (id)obj
{
	[[self window] center]; //Force us to load
	[self _refreshContents];
		
	[[NSApplication sharedApplication] beginSheet: [self window]
										modalForWindow: wind
										modalDelegate: self
										didEndSelector: @selector(_sheetDidEnd:returnCode:contextInfo:)
										contextInfo: (void *)CFBridgingRetain(obj)];
}

#pragma mark -

- (void)setKeyCombo: (PTKeyCombo*)combo
{
	mKeyCombo = combo;
	[self _refreshContents];
}

- (PTKeyCombo*)keyCombo
{
	return mKeyCombo;
}

- (void)setKeyBindingName: (NSString*)name
{
	mKeyName = name;
	[self _refreshContents];
}

- (NSString*)keyBindingName
{
	return mKeyName;
}

#pragma mark -

- (IBAction)ok: (id)sender
{
	if( [[self window] isSheet] )
		[[NSApplication sharedApplication] endSheet: [self window] returnCode: NSOKButton];
	else
		[[NSApplication sharedApplication] stopModalWithCode: NSOKButton];
}

- (IBAction)cancel: (id)sender
{
	if( [[self window] isSheet] )
		[[NSApplication sharedApplication] endSheet: [self window] returnCode: NSCancelButton];
	else
		[[NSApplication sharedApplication] stopModalWithCode: NSCancelButton];
}

- (IBAction)clear: (id)sender
{
	[self setKeyCombo: [PTKeyCombo clearKeyCombo]];

	if( [[self window] isSheet] )
		[[NSApplication sharedApplication] endSheet: [self window] returnCode: NSOKButton];
	else
		[[NSApplication sharedApplication] stopModalWithCode: NSOKButton];
}

- (void)noteKeyBroadcast: (NSNotification*)note
{
	PTKeyCombo* keyCombo;
	
	keyCombo = [note userInfo][@"keyCombo"];

	[self setKeyCombo: keyCombo];
}

@end
