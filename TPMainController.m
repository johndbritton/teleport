//
//  TPMainController.m
//  Teleport
//
//  Created by JuL on Thu Dec 25 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPMainController.h"
#import "TPClientController.h"
#import "TPServerController.h"
#import "TPNetworkConfigurationWatcher.h"
#import "TPStatusItemController.h"
#import "TPAuthenticationManager.h"
#import "TPRemoteHost.h"
#import "TPLocalHost.h"
#import "TPMessage.h"
#import "TPBonjourController.h"
#import "TPHostsManager.h"
#import "TPHostSnapping.h"
#import "TPPreferencesManager.h"
#import "TPTransfersManager.h"
#import "TPBezelController.h"
#import "TPPreferencePane.h"

#import <unistd.h>
#import <signal.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <sys/param.h>
#import <sys/mount.h>
#import <Security/AuthSession.h>
#import <Sparkle/Sparkle.h>

#import "TPNetworkConnection.h"
#import "TPTestsController.h"

typedef CGError CGSError;

extern CGSError	CPSGetFrontProcess( CPSProcessSerNum *pPSN);
extern CGSError CPSSetFrontProcess( const CPSProcessSerNum *pPSN);

#define VERSION_CHECK_URL @"https://johndbritton.com/teleport/appcast/stable.xml"

static TPMainController * _mainController = nil;

@interface TPMainController (Internal)

- (void)_checkAccessibility;
- (void)_checkEncryption;

@end

@implementation TPMainController

+ (TPMainController*)sharedController
{
	return _mainController;
}

- (BOOL)canBeControlledByHostWithIdentifier:(NSString*)identifier
{
	if([[TPClientController defaultController] isControlling]) {
		TPRemoteHost * controlledHost = [[[TPClientController defaultController] currentConnection] connectedHost];
		return ![[controlledHost identifier] isEqualToString:identifier];
	}
	else
		return YES;
}

- (BOOL)canControlHostWithIdentifier:(NSString*)identifier
{
	if([[TPServerController defaultController] isControlled]) {
		TPRemoteHost * controllingHost = [[[TPServerController defaultController] currentConnection] connectedHost];
		return ![[controllingHost identifier] isEqualToString:identifier];
	}
	else
		return YES;
}


#pragma mark -
#pragma mark Application delegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
#if RUN_TESTS
	[TPTestsController runTests];
#else
	_mainController = self;
	_frontProcessNum.lo = 0;
	
	/* Setup Notifications */
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_prefDidChange:) name:TPDefaultsDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_prefsDidUpgrade:) name:TPPreferencesDidUpgradeNotification object:nil];
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(screenDidLock:) name:@"com.apple.screenIsLocked" object:nil];
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(sessionDidResignActive:) name:NSWorkspaceSessionDidResignActiveNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(sessionDidBecomeActive:) name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(computerWillSleep:) name:NSWorkspaceWillSleepNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(computerDidWake:) name:NSWorkspaceDidWakeNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(screensDidSleep:) name:NSWorkspaceScreensDidSleepNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(screensDidWake:) name:NSWorkspaceScreensDidWakeNotification object:nil];
	[self _setupTimer];

	/* Waken controllers */
	[TPPreferencesManager sharedPreferencesManager];
	[TPClientController defaultController];
	[TPServerController defaultController];
	[TPStatusItemController defaultController];
	
	/* Watch the network configuration */
	_networkConfigurationWatcher = [[TPNetworkConfigurationWatcher alloc] init];
	[_networkConfigurationWatcher setDelegate:self];
	[_networkConfigurationWatcher startWatching];
	
	/* Data loading */
	[[TPHostsManager defaultManager] loadHosts];
	[[TPAuthenticationManager defaultManager] loadHosts];
	
	/* Browse on Bonjour */
	[[TPBonjourController defaultController] browse];
	
	/* Misc */
	[[TPTransfersManager manager] setDelegate:[TPBezelController defaultController]];
	
	/* Warning dialogs */
	[self performSelector:@selector(_showWarningDialogs) withObject:nil afterDelay:0.0];
	
	/* Auto-check version */
	if([[TPPreferencesManager sharedPreferencesManager] boolForPref:AUTOCHECK_VERSION])
		[self checkVersionsAndConfirm:NO];
		
	/* Setup initial host borders */
	[[TPClientController defaultController] updateTriggersAndShowVisualHint:YES];
	
	/* Notify that we're ready */
	[[TPHostsManager defaultManager] notifyChanges];
	
	NSArray *peeredHosts = [[TPHostsManager defaultManager] hostsWithState:TPHostPeeredState];
	if (peeredHosts.count == 0 && ![[TPPreferencesManager sharedPreferencesManager] boolForPref:ALLOW_CONTROL]) {
		[[TPPreferencePane preferencePane] showWindow:nil];
	}
	
#if 0
	[TPTestsController runFakeHostsTest];
#endif
#endif
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
	[[TPPreferencePane preferencePane] showWindow:nil];
	return YES;
}

- (void)_showWarningDialogs
{
	[self _checkAccessibility];
	[self _checkEncryption];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[[TPHostsManager defaultManager] saveHosts];
	[[TPAuthenticationManager defaultManager] saveHosts];
	
	if([[TPClientController defaultController] isControlling])
		[[TPClientController defaultController] stopControl];
	
	if([[TPServerController defaultController] allowControl])
		[[TPServerController defaultController] stopSharing];
}

- (void)applicationWillResignActive:(NSNotification *)aNotification
{
	if([[TPClientController defaultController] isControlling])
		[NSApp activateIgnoringOtherApps:YES];
}

//- (void)applicationDidResignActive:(NSNotification *)aNotification
//{
//	NSLog(@"did resign");
//	if([[TPClientController defaultController] isControlling]) {
//		NSLog(@"ACTIVATE");
//		[NSApp activateIgnoringOtherApps:YES];
//	}
//}

- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotification
{
	[[TPHostsManager defaultManager] notifyChanges];
	
	if([[TPServerController defaultController] allowControl]) {
		[[TPBonjourController defaultController] updateTXTRecordOfPublishService];
	}
	
	[[TPClientController defaultController] updateTriggersAndShowVisualHint:YES];
}

- (void)screenDidLock:(NSNotification*)notification
{
	TPClientController * clientController = [TPClientController defaultController];
	if([clientController isControlling])
		[clientController stopControl];
	if ([clientController currentConnection] != nil && [[TPPreferencesManager sharedPreferencesManager] boolForPref:SYNC_LOCK_STATUS]) {
		DebugLog(@"locking screens");
		TPMessage *message = [TPMessage messageWithType:TPControlLockType];
		[[clientController currentConnection] sendMessage:message];
	}
}

- (void)screensDidSleep:(NSNotification*)notification
{
	DebugLog(@"sleeping screens");
	[self _invalidateTimer];
	TPClientController * clientController = [TPClientController defaultController];
	TPMessage *message = [TPMessage messageWithType:TPControlSleepType];
	if ([clientController currentConnection] != nil && [[TPPreferencesManager sharedPreferencesManager] boolForPref:SYNC_SLEEP_STATUS]) {
		[[clientController currentConnection] sendMessage:message];
	}
}

- (void)screensDidWake:(NSNotification*)notification
{
	DebugLog(@"waking screens");
	[self _setupTimer];
	[self _sendWakeEvent];
}
- (void)sessionDidResignActive:(NSNotification*)notification
{
	TPClientController * clientController = [TPClientController defaultController];
	if([clientController isControlling])
		[clientController stopControl];
	else
		[clientController setCurrentConnection:nil];
	
	TPServerController * serverController = [TPServerController defaultController];
	if([serverController isControlled])
		[serverController stopControl];
	else
		[serverController setCurrentConnection:nil];
	
	if([serverController allowControl])
		[serverController stopSharing];
}

- (void)sessionDidBecomeActive:(NSNotification*)notification
{
	if([[TPServerController defaultController] allowControl])
		[[TPServerController defaultController] startSharing];
}

- (void)computerWillSleep:(NSNotification*)notification
{
	if([[TPClientController defaultController] isControlling])
		[[TPClientController defaultController] stopControl];
	
	if([[TPServerController defaultController] allowControl])
		[[TPServerController defaultController] stopSharing];
	
	[[TPHostsManager defaultManager] saveHosts];
	[[TPAuthenticationManager defaultManager] saveHosts];
}

- (void)computerDidWake:(NSNotification*)notification
{
	[[TPHostsManager defaultManager] notifyChanges];
	[[TPClientController defaultController] updateTriggersAndShowVisualHint:YES];
	
	CFDictionaryRef sessionInfoDict = CGSessionCopyCurrentDictionary();

	if(CFDictionaryGetValue(sessionInfoDict, kCGSessionOnConsoleKey) == kCFBooleanTrue && [[TPServerController defaultController] allowControl])
		[[TPServerController defaultController] startSharing];
	
	CFRelease(sessionInfoDict);
}

- (void)networkConfigurationDidChange:(TPNetworkConfigurationWatcher*)watcher
{
	DebugLog(@"Network configuration did change");
	
	if([[TPPreferencesManager sharedPreferencesManager] boolForPref:DISCONNECT_ON_NETWORK_CONFIG_CHANGE]) {
		TPServerController * server = [TPServerController defaultController];
		if([server allowControl]) {
			[server stopSharing];
			[server startSharing];
		}
		
		[[TPBonjourController defaultController] stopBrowsing];
		[[TPBonjourController defaultController] browse];
		
		[[TPClientController defaultController] stopControl];
	}
}


#pragma mark -
#pragma mark Misc

- (void)_setupTimer {
	if (_wakeTimer == nil) {
		DebugLog(@"Setting up timer");
		_wakeTimer = [NSTimer scheduledTimerWithTimeInterval:50.0f target:self selector:@selector(_triggerTimer:) userInfo:nil repeats:YES];
		_wakeTimer.tolerance = 8.0f;
	}
}

- (void)_invalidateTimer {
	DebugLog(@"invalidating timer");
	[_wakeTimer invalidate];
	_wakeTimer = nil;
}
- (void)_triggerTimer:(NSTimer *) timer {
	DebugLog(@"keeping screens awake");
	[self _sendWakeEvent];
}

- (void)_sendWakeEvent {
	TPClientController * clientController = [TPClientController defaultController];
	TPMessage *message = [TPMessage messageWithType:TPControlWakeType];
	if ([clientController currentConnection] != nil) {
		[[clientController currentConnection] sendMessage:message];
	}
}

- (void)_checkAccessibility
{
	if (![[TPLocalHost localHost] checkAccessibility]) {
		NSAlert * alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Disabled access for assistive devices", @"Text in dialog about accessibility") defaultButton:NSLocalizedString(@"OK", @"Button title") alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"The access for assistive devices has been disabled although teleport needs this to operate.\nPlease allow teleport and launch it again.", @"Explanation in dialog for accessibility")];
		
		int returnCode = [self presentAlert:alert];
		
		
		[NSApp terminate:nil];
	}
}

- (void)_checkEncryption
{
	if([[TPPreferencesManager sharedPreferencesManager] boolForPref:ENABLED_ENCRYPTION]) {
		if(![[TPLocalHost localHost] hasIdentity]) {
			NSAlert * alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Encryption requires a certificate", @"Text in dialog for certificate missing error") defaultButton:NSLocalizedString(@"Launch Assistant", @"Button title") alternateButton:NSLocalizedString(@"Disable Encryption", @"Button title") otherButton:nil informativeTextWithFormat:NSLocalizedString(@"In order to activate encryption, teleport needs a valid certificate, but couldn't find one in your Keychain.\nYou'll need to create a certificate and re-activate encryption. Note that the certificate algorithm and key size must match between the server and the clients.\n\nWould you like to launch Certificate Assistant to create a new self-signed certificate?\nRecommended settings: RSA 1024 bits, all others to default values.", @"Explanation in dialog for certificate missing error")];
			
			int returnCode = [self presentAlert:alert];
			
			[[TPPreferencesManager sharedPreferencesManager] setValue:@NO forKey:ENABLED_ENCRYPTION];
			
			switch(returnCode) {
				case NSAlertDefaultReturn:
					[[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.CertificateAssistant" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifier:NULL];
					break;
				case NSAlertAlternateReturn:
					break;
			}
		}
	}
	else
		[[TPLocalHost localHost] resetIdentity];
}

- (void)_prefDidChange:(NSNotification*)notification
{
	if([[notification object] isEqualToString:ENABLED_ENCRYPTION]) {
		[self _checkEncryption];
		[[TPLocalHost localHost] notifyChange];
	}
	else if([[notification object] isEqualToString:WAKE_ON_LAN]) {
		[[[TPHostsManager defaultManager] hostsWithState:TPHostPeeredOfflineState] makeObjectsPerformSelector:@selector(notifyChange)];
	}
	else if([[notification object] isEqualToString:CERTIFICATE_IDENTIFIER]) {
		[[TPLocalHost localHost] reloadIdentity];
	}
	else if([[notification object] isEqualToString:SHARED_SCREEN_INDEX]) {
		[[TPLocalHost localHost] notifyChange];
	}
}

#define TPTerminateDaemonNotification @"TPTerminateDaemonNotification"
- (void)_prefsDidUpgrade:(NSNotification*)notification
{
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:TPTerminateDaemonNotification object:nil userInfo:nil deliverImmediately:YES]; // be sure to quit previous teleport
}


#pragma mark -
#pragma mark UI

- (void)goFrontmost
{
	if(CPSGetFrontProcess(&_frontProcessNum) != kCGErrorSuccess) {
		_frontProcessNum.lo = 0;
		DebugLog(@"get front process failed");
	}
	else {
		DebugLog(@"get front process succeded: hi=%d low=%d", _frontProcessNum.hi, _frontProcessNum.lo);
	}
	
//	ProcessSerialNumber psn;
//	GetCurrentProcess(&psn);
//	SetFrontProcess(&psn);
	[NSApp activateIgnoringOtherApps:TRUE];
}

- (void)leaveFrontmost
{
	if(_frontProcessNum.lo > 0) {
		CPSSetFrontProcess(&_frontProcessNum);
		DebugLog(@"switched back to process hi=%d low=%d", _frontProcessNum.hi, _frontProcessNum.lo);
		_frontProcessNum.lo = 0;
	}
}

- (int)presentAlert:(NSAlert*)alert
{
	[self goFrontmost];
	int result = [alert runModal];
	[self leaveFrontmost];
	return result;
}


#pragma mark -
#pragma mark Version checking

- (void)checkVersionFromNotification:(NSNotification*)notification
{
	[self checkVersionsAndConfirm:YES];
}

- (void)checkVersionsAndConfirm:(BOOL)confirm
{
	if(confirm) {
		[[SUUpdater sharedUpdater] checkForUpdates:nil];
	}
	else {
		[[SUUpdater sharedUpdater] checkForUpdatesInBackground];
	}
}

//- (void)_handleCheckVersionWithDictionary:(NSDictionary*)productVersionDict
//{
//	
//	
////	NSNumber * confirm = [productVersionDict objectForKey:@"TPConfirm"];
////	NSString * currentBuildString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
////	if(currentBuildString == nil)
////		return;
////	int currentBuild = [currentBuildString intValue];
////	int latestBuild = [[productVersionDict objectForKey:@"build"] intValue];
////	NSString * latestVersionString = [productVersionDict objectForKey:@"version"];
////	
////	if(latestBuild > currentBuild) {
////		NSString * description = [productVersionDict valueForKey:@"description"];
////		NSString * info = [NSString stringWithFormat:NSLocalizedString(@"teleport %@ is now available.\n%@\n\nWould you like to download the new version now?", nil), latestVersionString, description];
////		
////		NSAlert * alert = [NSAlert alertWithMessageText:NSLocalizedString(@"A new version of teleport is available!", nil) defaultButton:NSLocalizedString(@"Yes", nil) alternateButton:NSLocalizedString(@"No", nil) otherButton:NSLocalizedString(@"Don't show again", nil) informativeTextWithFormat:info];
////		int result = [(TPMainController*)[NSApp delegate] presentAlert:alert];
////		
////		switch(result) {
////			case NSAlertDefaultReturn:
////				[self updateToVersion:latestVersionString fromURL:[productVersionDict objectForKey:@"url"]];
////				break;
////			case NSAlertAlternateReturn:
////				break;
////			case NSAlertOtherReturn:
////				[[TPPreferencesManager sharedPreferencesManager] setValue:[NSNumber numberWithBool:NO] forKey:AUTOCHECK_VERSION];
////				break;
////		}
////	}
////	else if(latestBuild < currentBuild) {
////		if([confirm boolValue]) {
////			NSAlert * alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Betatester!", nil) defaultButton:NSLocalizedString(@"OK", nil) alternateButton:nil otherButton:nil informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Your build (%d) is newer than the latest available (%d), so you must be a betatester. Congratulations!", nil), currentBuild, latestBuild]];
////			[(TPMainController*)[NSApp delegate] presentAlert:alert];
////		}
////	}
////	else {
////		if([confirm boolValue]) {
////			NSAlert * alert = [NSAlert alertWithMessageText:NSLocalizedString(@"teleport is up-to-date.", nil) defaultButton:NSLocalizedString(@"OK", nil) alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"You have the most recent version of teleport.", nil)];
////			[(TPMainController*)[NSApp delegate] presentAlert:alert];
////		}
////	}
//}

//- (void)threadedCheckVersionAndConfirm:(NSNumber*)confirm
//{
//	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//	
//	NSMutableDictionary * productVersionDict = [NSMutableDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:VERSION_CHECK_URL]];
//	if(productVersionDict == nil) {
//		[pool release];
//		return;
//	}
//	
//	[productVersionDict setObject:confirm forKey:@"TPConfirm"];
//	
//	[self performSelectorOnMainThread:@selector(_handleCheckVersionWithDictionary:) withObject:productVersionDict waitUntilDone:YES];
//	
//	[pool release];
//}
//
//- (void)updateToVersion:(NSString*)version fromURL:(NSString*)urlString
//{
//	NSURL * url = [NSURL URLWithString:urlString];
//	[[NSWorkspace sharedWorkspace] openURL:url];
//}

@end
