//
//  TPPreferencePane.m
//  Teleport
//
//  Created by JuL on Mon Dec 08 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPPreferencePane.h"

#import <SecurityInterface/SFCertificatePanel.h>
#import <SecurityInterface/SFChooseIdentityPanel.h>
#import <Sparkle/Sparkle.h>

#import "TPLayoutView.h"
#import "TPRemoteHost.h"
#import "TPVersionTextField.h"
#import "TPPreferencesManager.h"
#import "TPHostsManager.h"
#import "TPLocalHost.h"
#import "TPAuthenticationManager.h"
#import "TPMainController.h"

#define LAYOUT_HEIGHT 500
#define OPTIONS_HEIGHT 250

@implementation TPPreferencePane
{
	BOOL hasPendingLayoutUpdates;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		hasPendingLayoutUpdates = NO;
	}
	return self;
}

+ (instancetype)preferencePane
{
	static TPPreferencePane *prefPane = nil;
	if (prefPane == nil) {
		prefPane = [[TPPreferencePane alloc] initWithWindowNibName:@"teleportPref"];
	}
	
	return prefPane;
}

- (void)windowDidLoad
{
#if ! LEGACY_BUILD
	if([[TPLocalHost localHost] osVersion] >= TPHostOSVersion(6)) {
		[logoView setEnabled:YES];
	}
#endif
	
	NSBundle * mainBundle = [NSBundle bundleForClass:[self class]];
	NSDictionary * infoDict = [mainBundle infoDictionary];
	NSDictionary * localizedInfoDict = [mainBundle localizedInfoDictionary];
	
	NSString * publicVersion = infoDict[@"CFBundleVersion"];
	NSString * buildVersion = infoDict[@"TPRevision"];
	NSString * translationInfo = localizedInfoDict[@"TPTranslationInfoString"];
	
	NSArray * versions = @[[NSString stringWithFormat:NSLocalizedString(@"Version %@", nil), publicVersion],
									[NSString stringWithFormat:NSLocalizedString(@"Build %@", nil), buildVersion]];
	
	if (translationInfo != nil) {
		versions = [versions arrayByAddingObject:translationInfo];
	}
	
	[versionTextField setVersions:versions];
	
	NSCell * buttonCell = [[trustedHostsTableView tableColumnWithIdentifier:@"certificate"] dataCell];
	[buttonCell setTarget:self];
	[buttonCell setAction:@selector(showTrustedCertificate:)];
	
	BOOL hasSeveralPotentialIdentities = ([[[TPLocalHost localHost] potentialIdentities] count] > 1);
	[showCertificateButton setHidden:hasSeveralPotentialIdentities];
	[chooseCertificateButton setHidden:!hasSeveralPotentialIdentities];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(needUpdateLayout) name:TPHostsConfigurationDidChangeNotification object:nil];
}

- (void)showWindow:(id)sender
{
	[super showWindow:sender];
	[NSApp activateIgnoringOtherApps:YES];

	if (hasPendingLayoutUpdates) {
		[layoutView updateLayout];
		hasPendingLayoutUpdates = NO;
	}
}

- (SUUpdater *)updater
{
	return [SUUpdater sharedUpdater];
}


#pragma mark -
#pragma mark IBActions

- (IBAction)showAboutSheet:(id)sender
{
	[NSApp beginSheet:aboutWindow modalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (void)closeAboutSheet
{
	//DebugLog(@"closeAboutSheet");
	[NSApp endSheet:aboutWindow];
	[aboutWindow orderOut:nil];
}

- (TPPreferencesManager*)prefs
{
	return [TPPreferencesManager sharedPreferencesManager];
}

- (TPLocalHost*)localHost
{
	return [TPLocalHost localHost];
}


#pragma mark -
#pragma mark Add other

- (IBAction)addOther:(id)sender
{
#if 0
	[addOtherAddressField setStringValue:@""];
	[NSApp beginSheet:addOtherSheet modalForWindow:[[self mainView] window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
#endif
}

- (IBAction)closeAddOther:(id)sender
{
#if 0
	[NSApp endSheet:addOtherSheet];
	[addOtherSheet close];
#endif
}

- (IBAction)confirmAddOther:(id)sender
{
#if 0
	NSString * name = [addOtherNameField stringValue];
	NSString * address = [addOtherAddressField stringValue];
	NSSize screenSize;
	
	screenSize.width = [addOtherWidthField floatValue];
	screenSize.height = [addOtherHeightField floatValue];
	
	DebugLog(@"adding %@ (%@) width size %@", name, address, NSStringFromSize(screenSize));
	
	TPRemoteHost * remoteHost = [[TPRemoteHost alloc] initWithIdentifier:name address:address];
	
	[remoteHost setComputerName:name];
	[remoteHost setScreenSize:screenSize];
	
	[remoteHost release];
	[self closeAddOther:sender];
#endif
}


#pragma mark -
#pragma mark Authentication

- (void)showAuthenticationPendingDialog:(NSNotification*)notification
{
	TPRemoteHost * remoteHost = [[TPHostsManager defaultManager] hostWithIdentifier:[notification object]];
	NSString * msgString = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Asking host \\U201C%@\\U201D for trust", nil, [NSBundle bundleForClass:[self class]], @"Trust request dialog"), [remoteHost computerName]];
	_alertPanel = NSGetAlertPanel(msgString,NSLocalizedStringFromTableInBundle(@"You should now grant the trust on your other Mac.", nil, [NSBundle bundleForClass:[self class]], @"Trust request message"),NSLocalizedStringFromTableInBundle(@"Cancel", nil, [NSBundle bundleForClass:[self class]], @"Generic cancel button in dialog"),nil,nil);
	[NSApp beginSheet:_alertPanel modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:(void *)CFBridgingRetain(remoteHost)];
}

- (void)closeAuthenticationPendingDialog:(NSNotification*)notification
{
	if(_alertPanel != nil) {
		[NSApp endSheet:_alertPanel];
	}	
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	TPRemoteHost * remoteHost = (__bridge TPRemoteHost*)contextInfo;

	switch(returnCode) {
		case NSAlertDefaultReturn:
			[remoteHost setHostState:TPHostSharedState];
			[[TPAuthenticationManager defaultManager] abortAuthenticationRequest];
			break;
		default:
			break;
	}

	[sheet close];
	_alertPanel = nil;
}

	
#pragma mark -
#pragma mark Trusted hosts

- (BOOL)tableView:(NSTableView*)tableView handleKeyDown:(NSEvent*)event
{
	BOOL handled = NO;
	
	NSString * string = [event charactersIgnoringModifiers];
	if([string length] > 0) {
		unichar c = [string characterAtIndex:0];
		switch(c) {
			case 127: // backspace
				[self deleteTrustedHost:tableView];
				handled = YES;
				break;
			default:
				break;
		}
	}
	
	return handled;
}

- (IBAction)showTrustedHosts:(id)sender
{
	[self reloadTrustedHosts];
	[NSApp beginSheet:trustedHostsWindow modalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction)closeTrustedHosts:(id)sender
{
	[NSApp endSheet:trustedHostsWindow];
    [trustedHostsWindow orderOut:nil];
}

- (IBAction)deleteTrustedHost:(id)sender
{
	NSIndexSet * selectedRows = [trustedHostsTableView selectedRowIndexes];
#if LEGACY_BUILD
	unsigned currentIndex;
#else
	NSUInteger currentIndex;
#endif
	currentIndex = [selectedRows firstIndex];
	while (currentIndex != NSNotFound) {
		TPRemoteHost * trustedHost = _trustedHosts[currentIndex];
		[[TPAuthenticationManager defaultManager] host:trustedHost setTrusted:NO];
		currentIndex = [selectedRows indexGreaterThanIndex:currentIndex];
	}
	
	[self reloadTrustedHosts];
}

#if LEGACY_BUILD
- (int)numberOfRowsInTableView:(NSTableView *)tableView
#else
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
#endif
{
	return [_trustedHosts count];
}

#if LEGACY_BUILD
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
#else
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
#endif
{
	TPRemoteHost * remoteHost = _trustedHosts[row];
	NSString * identifier = [tableColumn identifier];
	
	if([identifier isEqualToString:@"name"])
		return remoteHost==nil?NSLocalizedStringFromTableInBundle(@"unknown name", nil, [NSBundle bundleForClass:[self class]], @"Name of unknown trusted host"):[remoteHost computerName];
	else if([identifier isEqualToString:@"address"])
		return remoteHost==nil?NSLocalizedStringFromTableInBundle(@"unknown address", nil, [NSBundle bundleForClass:[self class]], @"Address of unknown trusted host"):[remoteHost address];
	
	return nil;
}

#if LEGACY_BUILD
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row
#else
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
#endif
{
	NSString * identifier = [tableColumn identifier];
	
	if([identifier isEqualToString:@"certificate"]) {
		TPRemoteHost * remoteHost = _trustedHosts[row];
		[cell setEnabled:[remoteHost isCertified]];
	}
}

- (IBAction)showTrustedCertificate:(id)sender
{
	TPRemoteHost * remoteHost = _trustedHosts[[sender clickedRow]];

	NSData * certificateData = [remoteHost certificateData];
	OSErr err;
	CSSM_DATA cssmCertData = {[certificateData length], (uint8 *)[certificateData bytes]};
	SecCertificateRef certRef;
	if((err = SecCertificateCreateFromData(&cssmCertData, CSSM_CERT_UNKNOWN, CSSM_CERT_ENCODING_UNKNOWN, &certRef)) != noErr)
		NSLog(@"Error reading certificate for %@: %d", self, err);
	else {
		[[SFCertificatePanel sharedCertificatePanel] beginSheetForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL certificates:@[(__bridge id)certRef] showGroup:NO];
		CFRelease(certRef);
	}
}

- (void)reloadTrustedHosts
{
	_trustedHosts = [[TPAuthenticationManager defaultManager] trustedHosts];
	[trustedHostsTableView reloadData];
}

- (IBAction)checkVersion:(id)sender
{
	[[TPMainController sharedController] checkVersionsAndConfirm:YES];
}

- (IBAction)showCertificateViewer:(id)sender
{
	SecIdentityRef identityRef = [[TPLocalHost localHost] identity];
	
	if(identityRef != NULL) {
		SecCertificateRef certRef;
		SecIdentityCopyCertificate(identityRef, &certRef);
		if(certRef != NULL) {
			[[SFCertificatePanel sharedCertificatePanel] beginSheetForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL certificates:@[(__bridge id)certRef] showGroup:NO];
			CFRelease(certRef);
		}
	}
}

- (IBAction)showCertificateChooser:(id)sender
{
	SFChooseIdentityPanel * chooserPanel = [SFChooseIdentityPanel sharedChooseIdentityPanel];
	
	[chooserPanel setAlternateButtonTitle:NSLocalizedStringFromTableInBundle(@"Cancel", nil, [NSBundle bundleForClass:[self class]], @"Generic cancel button in dialog")];
	
	if([chooserPanel respondsToSelector:@selector(setInformativeText:)]) {
		[(id)chooserPanel setInformativeText:NSLocalizedStringFromTableInBundle(@"Select the certificate to be used for encryption. It must have the same encryption algorithm as the one used on the other Macs.", nil, [NSBundle bundleForClass:[self class]], @"Informative text in certificate selection panel")];
	}
	
	[chooserPanel beginSheetForWindow:[self window] modalDelegate:self didEndSelector:@selector(chooseIdentitySheetDidEnd:returnCode:contextInfo:) contextInfo:(__bridge void *)(chooserPanel) identities:[[TPLocalHost localHost] potentialIdentities] message:NSLocalizedStringFromTableInBundle(@"Choose certificate", nil, [NSBundle bundleForClass:[self class]], @"Title in certificate selection panel")];
}
	 
- (void)chooseIdentitySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if(returnCode == NSOKButton) {
		SFChooseIdentityPanel * chooserPanel = (__bridge SFChooseIdentityPanel*)contextInfo;
		SecIdentityRef identity = [chooserPanel identity];
		[[self localHost] setIdentity:identity];
	}
}

- (void)needUpdateLayout
{
	DebugLog(@"TPPReferencePane@%p#needUpdateLayout, window=%p, visible=%d", self, self.window, self.window.isVisible);
	if (self.window && self.window.isVisible) {
		[layoutView updateLayout];
	} else {
		hasPendingLayoutUpdates = YES;
	}
}

@end
