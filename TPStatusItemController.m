//
//  TPStatusItemController.m
//  teleport
//
//  Created by JuL on 20/05/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import "TPStatusItemController.h"

#import "TPMainController.h"
#import "TPServerController.h"
#import "TPClientController.h"
#import "TPPreferencesManager.h"
#import "TPLocalHost.h"
#import "TPPreferencePane.h"

static TPStatusItemController * _defaultController = nil;

@interface NSStatusItem (AppKitPrivate)

@property (nonatomic, readonly, strong) NSButton *_button;

@end

@implementation TPStatusItemController

+ (TPStatusItemController*)defaultController
{
	if(_defaultController == nil)
		_defaultController = [[TPStatusItemController alloc] init];
	return _defaultController;
}

- (instancetype) init
{
	self = [super init];
	
	_statusItem = nil;
	
	self.showStatusItem = YES;
	
	return self;
}


- (void)setShowStatusItem:(BOOL)showStatusItem
{
	if(showStatusItem && _statusItem == nil) {
		_statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
		
		[_statusItem setImage:[NSImage imageNamed:@"menuicon"]];
		[_statusItem setAlternateImage:[NSImage imageNamed:@"menuicon-white"]];
		[_statusItem setHighlightMode:YES];
		
		[[[_statusItem _button] cell] setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
		
		NSMenu * menu = [[NSMenu alloc] init];
		
		NSMenuItem * sharedMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Share this Mac", nil) action:@selector(switchMenuItem:) keyEquivalent:@""];
		[sharedMenuItem setTarget:self];
		[sharedMenuItem setRepresentedObject:ALLOW_CONTROL];
		[sharedMenuItem bind:@"state" toObject:[TPPreferencesManager sharedPreferencesManager] withKeyPath:ALLOW_CONTROL options:nil];
		[menu addItem:sharedMenuItem];
		
		NSMenuItem * syncPasteboardMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Synchronize pasteboard", nil) action:@selector(switchMenuItem:) keyEquivalent:@""];
		[syncPasteboardMenuItem setTarget:self];
		[syncPasteboardMenuItem setRepresentedObject:SHARE_PASTEBOARD];
		[syncPasteboardMenuItem bind:@"state" toObject:[TPPreferencesManager sharedPreferencesManager] withKeyPath:SHARE_PASTEBOARD options:nil];
		[menu addItem:syncPasteboardMenuItem];
		
		NSMenuItem * dragDropFilesMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Drag & Drop files", nil) action:@selector(switchMenuItem:) keyEquivalent:@""];
		[dragDropFilesMenuItem setTarget:self];
		[dragDropFilesMenuItem setRepresentedObject:COPY_FILES];
		[dragDropFilesMenuItem bind:@"enabled" toObject:[TPLocalHost localHost] withKeyPath:@"supportDragNDrop" options:nil];
		[dragDropFilesMenuItem bind:@"state" toObject:[TPPreferencesManager sharedPreferencesManager] withKeyPath:COPY_FILES options:nil];
		[menu addItem:dragDropFilesMenuItem];

		NSMenuItem * syncLockStatusMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Sync lock status", nil) action:@selector(switchMenuItem:) keyEquivalent:@""];
		[syncLockStatusMenuItem setTarget:self];
		[syncLockStatusMenuItem setRepresentedObject:SYNC_LOCK_STATUS];
		[syncLockStatusMenuItem bind:@"state" toObject:[TPPreferencesManager sharedPreferencesManager] withKeyPath:SYNC_LOCK_STATUS options:nil];
		[menu addItem:syncLockStatusMenuItem];
		
		NSMenuItem * syncSleepStatusMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Sync sleep status", nil) action:@selector(switchMenuItem:) keyEquivalent:@""];
		[syncSleepStatusMenuItem setTarget:self];
		[syncSleepStatusMenuItem setRepresentedObject:SYNC_SLEEP_STATUS];
		[syncSleepStatusMenuItem bind:@"state" toObject:[TPPreferencesManager sharedPreferencesManager] withKeyPath:SYNC_SLEEP_STATUS options:nil];
		[menu addItem:syncSleepStatusMenuItem];

		[menu addItem:[NSMenuItem separatorItem]];
		
		NSMenuItem * openPrefPanelMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Configure\\U2026", nil) action:@selector(openTeleportPanel) keyEquivalent:@""];
		[openPrefPanelMenuItem setTarget:self];

		[menu addItem:[NSMenuItem separatorItem]];
		
#if DEBUG_BUILD
		NSMenuItem * disconnectMenuItem = [menu addItemWithTitle:@"Disconnect" action:@selector(disconnect) keyEquivalent:@""];
		[disconnectMenuItem setTarget:self];
#endif
		
		NSMenuItem * quitMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Quit teleport", nil) action:@selector(quitApp) keyEquivalent:@""];
		[quitMenuItem setTarget:self];
		
		[_statusItem setMenu:menu];
	}
	else if(!showStatusItem && _statusItem != nil) {
		[[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
		_statusItem = nil;
	}
}

- (BOOL)showStatusItem
{
	return (_statusItem != nil);
}

- (void)updateWithStatus:(TPStatus)status host:(TPRemoteHost*)host
{
	if(_statusItem != nil && [[TPPreferencesManager sharedPreferencesManager] boolForPref:SHOW_TEXTUAL_STATUS]) {
		NSString * title = nil;
		
		switch(status) {
			case TPStatusIdle:
				title = nil;
				break;
			case TPStatusControlled:
				title = [NSString stringWithFormat:NSLocalizedString(@"controlled by %@", nil), [host computerName]];
				break;
			case TPStatusControlling:
				title = [NSString stringWithFormat:NSLocalizedString(@"controlling %@", nil), [host computerName]];
				break;
		}
		
		NSDisableScreenUpdates();
		[_statusItem setTitle:title];
		NSEnableScreenUpdates();
	}
}

#if DEBUG_BUILD
- (void)disconnect
{
	[[TPClientController defaultController] stopControl];
}
#endif

- (void)quitApp
{
	[NSApp terminate:self];
}

- (void)switchMenuItem:(id)sender
{
	[[TPPreferencesManager sharedPreferencesManager] setValue:[NSNumber numberWithBool:![sender state]] forKey:[sender representedObject]];
}

- (void)openTeleportPanel
{
	[[TPPreferencePane preferencePane] showWindow:nil];
}

@end
