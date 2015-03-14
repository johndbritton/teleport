//
//  TPClientController.m
//  Teleport
//
//  Created by JuL on Wed Dec 03 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPClientController.h"
#import "TPMainController.h"
#import "TPAuthenticationManager.h"
#import "TPEventsController.h"
#import "TPBezelController.h"
#import "TPStatusItemController.h"
#import "TPNetworkConnection.h"
#import "TPTransfersManager.h"
#import "TPPreferencesManager.h"
#import "TPHostAnimationController.h"
#import "TPRemoteHost.h"
#import "TPLocalHost.h"
#import "TPHotBorder.h"
#import "TPMessage.h"

#import "TPHostsManager.h"
#import "TPConnectionsManager.h"

#import "PTHotKeyCenter.h"
#import "PTKeyBroadcaster.h"

#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>

#include <mach/mach_port.h>
#include <mach/mach_interface.h>
#include <mach/mach_init.h>

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>

#define HOTBORDER_SAFE_MARGIN 3

static TPClientController * _defaultClientController = nil;

@interface TPClientController (Internal)

- (void)_startSleepPrevention;
- (void)_stopSleepPrevention;
- (NSDictionary*)_clientOptionsForRemoteHost:(TPRemoteHost*)remoteHost;

@end

@implementation TPClientController

+ (TPClientController*)defaultController
{
	if(_defaultClientController == nil)
		_defaultClientController = [[TPClientController alloc] init];
	
	return _defaultClientController;
}

- (instancetype) init
{
	self = [super init];
	
	_hotBorders = [[NSMutableDictionary alloc] init];
	_hotKeys = [[NSMutableDictionary alloc] init];
	_sleepService = IO_OBJECT_NULL;
	_state = TPClientIdleState;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTriggers:) name:TPHostDidUpdateNotification object:nil];
	
	return self;
}



#pragma mark -
#pragma mark Hot borders

- (TPHotBorder*)currentHotBorder
{
	TPNetworkConnection * currentConnection = [self currentConnection];
	if(currentConnection == nil)
		return nil;
	
	TPRemoteHost * host = [currentConnection connectedHost];
	if(host == nil)
		return nil;
	
	return _hotBorders[[host identifier]];
}

- (void)_updateTriggersForHost:(TPRemoteHost*)host showVisualHint:(BOOL)showVisualHint
{
	if(![host isKindOfClass:[TPRemoteHost class]])
		return;
	
	BOOL canControl = [(TPMainController*)[NSApp delegate] canControlHostWithIdentifier:[host identifier]];
	BOOL canWakeOnLAN = [host isInState:TPHostPeeredOfflineState] && [host hasValidMACAddress] && [[TPPreferencesManager sharedPreferencesManager] boolForPref:WAKE_ON_LAN];
	BOOL shouldEnableTriggers = canControl && (([host isInState:TPHostPeeredOnlineState | TPHostControlledState]) || canWakeOnLAN);
	BOOL shouldActivateHotBorder = ![host isInState:TPHostControlledState];
	NSString * identifier = [host identifier];
	
	TPHotBorder * hotBorder = _hotBorders[identifier];
	PTHotKey * hotKey = _hotKeys[identifier];
	
	DebugLog(@"updating hot border %@ for host %@: show: %d activate: %d", hotBorder, host, shouldEnableTriggers, shouldActivateHotBorder);
	
	// Hot border
	if(hotBorder != nil) {
		if(shouldEnableTriggers) {
			[hotBorder updateWithRepresentingRect:[host adjustedHostRect] inRect:[[host localScreen] frame]];
			
			if(shouldActivateHotBorder && [hotBorder state] == TPHotBorderInactiveState) {
				[hotBorder delayedActivate];
			}
			else if(!shouldActivateHotBorder && [hotBorder state] != TPHotBorderInactiveState) {
				[hotBorder deactivate];
			}
		}
		else {
			DebugLog(@"remove hot border %@ with id %@", hotBorder, identifier);
			[hotBorder deactivate];
			[self takeDownHotBorder:hotBorder];
			[hotBorder close];
			[_hotBorders removeObjectForKey:identifier];
		}
	}
	else if(shouldEnableTriggers) {
		hotBorder = [TPHotBorder hotBorderRepresentingRect:[host adjustedHostRect] inRect:[[host localScreen] frame]];
		[hotBorder setDelegate:self];
		[hotBorder setIdentifier:identifier];
		[self setupHotBorder:hotBorder forHost:host];
		_hotBorders[identifier] = hotBorder;
		
		if(shouldActivateHotBorder) {
			[hotBorder delayedActivate];
		}
		
		DebugLog(@"add hot border %@ with id %@", hotBorder, identifier);
	}
	
	if(showVisualHint && shouldEnableTriggers && shouldActivateHotBorder && [host isInState:TPHostPeeredOnlineState] && [host previousHostState] != TPHostControlledState) {
		[[TPHostAnimationController controller] showAppearanceAnimationForHost:host];
	}
	
	// Hot key
	PTKeyCombo * keyCombo = [host keyCombo];
	BOOL isValidKeyCombo = (keyCombo != nil) && ![keyCombo isClearCombo] && [keyCombo isValidHotKeyCombo];
	BOOL enableKeyCombo = shouldEnableTriggers && isValidKeyCombo;

	if(enableKeyCombo) {
		if(hotKey != nil && ![[hotKey keyCombo] isEqual:keyCombo]) {
			[[PTHotKeyCenter sharedCenter] unregisterHotKey:hotKey];
			hotKey = nil;
		}
		
		if(hotKey == nil) {
			hotKey = [[PTHotKey alloc] initWithIdentifier:identifier keyCombo:keyCombo];
			[hotKey setTarget:self];
			[hotKey setAction:@selector(hotKeyPressed:)];
			[[PTHotKeyCenter sharedCenter] registerHotKey:hotKey];
			_hotKeys[identifier] = hotKey;
		}
	}
	else if(hotKey != nil) {
		[[PTHotKeyCenter sharedCenter] unregisterHotKey:hotKey];		
		[_hotKeys removeObjectForKey:identifier];
	}
}

- (void)updateTriggers:(NSNotification*)notification
{
	TPRemoteHost * host = [notification object];
	[self _updateTriggersForHost:host showVisualHint:YES];
}

- (void)updateTriggersAndShowVisualHint:(BOOL)showVisualHint
{
#if DEBUG_GENERAL
	DebugLog(@"client: startWaiting");
#endif
	
	NSArray * hosts = [[TPHostsManager defaultManager] hostsWithState:TPHostAllStates];
	NSEnumerator * hostEnum = [hosts objectEnumerator];
	TPRemoteHost * host;
	
	while((host = [hostEnum nextObject]) != nil) {
		[self _updateTriggersForHost:host showVisualHint:showVisualHint];
	}
}

- (float)hotBorderSwitchDelay:(TPHotBorder*)hotBorder
{
	TPRemoteHost * remoteHost = [[TPHostsManager defaultManager] hostWithIdentifier:[hotBorder identifier]];
	if(![[remoteHost optionForKey:DELAYED_SWITCH] boolValue]) {
		return 0.0;
	}
	else {
		return [[remoteHost optionForKey:SWITCH_DELAY] floatValue];
	}
}

- (BOOL)hotBorder:(TPHotBorder*)hotBorder canFireWithEvent:(NSEvent*)event
{
	if(![(TPMainController*)[NSApp delegate] canControlHostWithIdentifier:[hotBorder identifier]])
		return NO;
	
#if ! LEGACY_BUILD
	NSArray * applicationsIgnoringTeleport = [[TPPreferencesManager sharedPreferencesManager] valueForPref:APPLICATIONS_DISABLING_TELEPORT];
	if(applicationsIgnoringTeleport != nil) {
		NSDictionary * activeApplication = [[NSWorkspace sharedWorkspace] activeApplication];
		NSString * currentApplicationIdentifier = activeApplication[@"NSApplicationBundleIdentifier"];
		if(currentApplicationIdentifier != nil) {
			for(NSString * ignoringApp in applicationsIgnoringTeleport) {
				if([ignoringApp isEqualToString:currentApplicationIdentifier]) {
					DebugLog(@"Ignoring switch because of ignoring app: %@", ignoringApp);
					return NO;
				}
			}
		}
	}
#endif
	
	TPRemoteHost * remoteHost = [[TPHostsManager defaultManager] hostWithIdentifier:[hotBorder identifier]];
	BOOL requireKey = [[remoteHost optionForKey:REQUIRE_KEY] boolValue];
	int keyTag = [[remoteHost optionForKey:SWITCH_KEY_TAG] intValue];
	return [[TPEventsController defaultController] event:event hasRequiredKeyIfNeeded:requireKey withTag:keyTag];
}

- (BOOL)hotBorder:(TPHotBorder*)hotBorder firedAtLocation:(NSPoint)location withDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	TPRemoteHost * remoteHost = [[TPHostsManager defaultManager] hostWithIdentifier:[hotBorder identifier]];
	
	if([remoteHost hostState] == TPHostPeeredOnlineState) {
#if DEBUG_BUILD
		BOOL isLocalHost = [remoteHost isEqual:[TPLocalHost localHost]];
		
		if(!isLocalHost) {
			[self requestStartControlOnHost:remoteHost atLocation:location withDraggingInfo:draggingInfo];
		}
#else
		[self requestStartControlOnHost:remoteHost atLocation:location withDraggingInfo:draggingInfo];	
#endif
		
		return [super hotBorder:hotBorder firedAtLocation:location withDraggingInfo:draggingInfo];
	}
	else if([remoteHost hostState] == TPHostPeeredOfflineState && [remoteHost hasValidMACAddress] && [[TPPreferencesManager sharedPreferencesManager] boolForPref:WAKE_ON_LAN]) {
		if(![[TPConnectionsManager manager] wakeUpHost:remoteHost])
			[remoteHost invalidateMACAddress];
		else
			[hotBorder activate];
	}
	
	return NO;
}

- (void)hotKeyPressed:(PTHotKey*)hotKey
{
	NSString * identifier = [hotKey identifier];
	TPRemoteHost * remoteHost = [[TPHostsManager defaultManager] hostWithIdentifier:identifier];
	TPHotBorder * hotBorder = _hotBorders[identifier];
	
	if([remoteHost hostState] == TPHostPeeredOnlineState) {
		NSPoint location = NSMakePoint(-1.0, -1.0);
#if DEBUG_BUILD
		BOOL isLocalHost = [remoteHost isEqual:[TPLocalHost localHost]];
		
		if(!isLocalHost) {
			[self requestStartControlOnHost:remoteHost atLocation:location withDraggingInfo:nil];
		}
#else
		[self requestStartControlOnHost:remoteHost atLocation:location withDraggingInfo:nil];	
#endif
		
		if(hotBorder != nil) {
			[super hotBorder:hotBorder firedAtLocation:NSZeroPoint withDraggingInfo:nil];
		}
	}
	else if([remoteHost hostState] == TPHostPeeredOfflineState && [remoteHost hasValidMACAddress] && [[TPPreferencesManager sharedPreferencesManager] boolForPref:WAKE_ON_LAN]) {
		if(![[TPConnectionsManager manager] wakeUpHost:remoteHost])
			[remoteHost invalidateMACAddress];
		else if(hotBorder != nil) {
			[hotBorder activate];
		}
	}
}


#pragma mark -
#pragma mark Start control

- (void)requestStartControlOnHost:(TPRemoteHost*)remoteHost atLocation:(NSPoint)location withDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	DebugLog(@"request start control on %@", remoteHost);
	
	if(remoteHost == nil || [remoteHost hostState] != TPHostPeeredOnlineState || _state != TPClientIdleState)
		return;
	
	NSMutableDictionary * infoDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									  [NSValue valueWithPoint:location], TPMousePositionKey,
									  nil];
	
	[self addDraggingInfo:draggingInfo toInfoDict:infoDict];
	
	/* Do the fake mouse up */
	if(draggingInfo != nil) {
		[[TPEventsController defaultController] mouseUpAtPosition:[NSEvent mouseLocation]];
	}
	
	/* Re-use existing connection if possible */
	BOOL shouldConnect = YES;
	TPNetworkConnection * currentConnection = [self currentConnection];
	if(currentConnection != nil) {
		if([currentConnection isValidForHost:remoteHost]) {
			[self sendStartControlRequestForConnection:currentConnection withInfoDict:infoDict];
			shouldConnect = NO;
		}
		else {
			[self setCurrentConnection:nil];
		}
	}
	
	if(shouldConnect) {
		_state = TPClientConnectingState;
		[[TPConnectionsManager manager] connectToHost:remoteHost withDelegate:self infoDict:infoDict];
	}
}

- (void)sendStartControlRequestForConnection:(TPNetworkConnection*)connection withInfoDict:(NSDictionary*)infoDict
{
	TPRemoteHost * controlledHost = [connection connectedHost];
	
	NSPoint mousePosition = [infoDict[TPMousePositionKey] pointValue];
	
	[self setCurrentConnection:connection];
	
	NSRect clientScreenRect = [[controlledHost localScreen] frame];
	NSRect serverScreenRect = [controlledHost adjustedHostRect];
	
	NSRect screenPlacement = clientScreenRect;
	screenPlacement.origin.x -= NSMinX(serverScreenRect);
	screenPlacement.origin.y -= NSMinY(serverScreenRect);	

	NSRect hotRect = [TPHotBorder hotRectWithRepresentingRect:clientScreenRect inRect:serverScreenRect];
	
	DebugLog(@"clientRect=%@ serverRect=%@ hotRect=%@ mousePosition=%@", NSStringFromRect(clientScreenRect), NSStringFromRect(serverScreenRect), NSStringFromRect(hotRect), NSStringFromPoint(mousePosition));
	
//	NSPoint mousePosition;
//	mousePosition.x = NSMinX(hotRect) + mouseLocation.x - NSMinX(serverScreenRect);
//	mousePosition.y = NSHeight(serverScreenRect) - (NSMinY(hotRect) + mouseLocation.y - NSMinY(serverScreenRect));
	
	_infoDict = infoDict; // XXX do this better
	
	/* Initiate connection */
	NSDictionary * clientOptions = [self _clientOptionsForRemoteHost:controlledHost];
	TPMessage * message = [TPMessage messageWithType:TPControlRequestMsgType
										 andInfoDict:@{TPScreenIndexKey: [NSData dataWithInt:[controlledHost sharedScreenIndex]],
													  TPScreenPlacementKey: [NSData dataWithRect:screenPlacement],
													  TPMousePositionKey: [NSData dataWithPoint:mousePosition],
													  TPSwitchOptionsKey: clientOptions}];
	
	[[self currentConnection] sendMessage:message];
}

- (void)startControl
{
#if DEBUG_GENERAL
	DebugLog(@"client: startControl");
#endif
	
	TPRemoteHost * controlledHost = [[self currentConnection] connectedHost];
	
	/* Update status menu */
	[[TPStatusItemController defaultController] updateWithStatus:TPStatusControlling host:controlledHost];
	
	/* Change state of controlled host */
	[controlledHost setHostState:TPHostControlledState];

	/* Deactivate hot borders */
	[self updateTriggersAndShowVisualHint:NO];
	
	/* Activate bezel */
	if(![[TPPreferencesManager sharedPreferencesManager] boolForPref:HIDE_CONTROL_BEZEL]) {
		[[TPBezelController defaultController] showBezelWithControlledHost:controlledHost];
	}
	
	/* Play sound */
	if([[TPPreferencesManager sharedPreferencesManager] boolForPref:PLAY_SWITCH_SOUND]) {
		[self playSwitchSound];
	}
	
	/* Begin transfers */
	[self beginTransfersWithInfoDict:_infoDict];
	_infoDict = nil;
	
	/* Activate events recorder */
	[self updateEventsController];
	[[self eventsController] startGettingEventsForListener:self onScreen:[controlledHost localScreen]];
	
	/* Start preventing the Mac to go to sleep */
	[self _startSleepPrevention];
	
	_state = TPClientControllingState;
}

- (NSDictionary*)_clientOptionsForRemoteHost:(TPRemoteHost*)remoteHost
{
	NSString * optionKeys[] = {
		REQUIRE_KEY,
		SWITCH_WITH_DOUBLE_TAP,
		SHARE_PASTEBOARD,
		DELAYED_SWITCH,
		SWITCH_DELAY,
		LIMIT_PASTEBOARD_SIZE,
		MAX_PASTEBOARD_SIZE,
		SWITCH_KEY_TAG,
		REQUIRE_PASTEBOARD_KEY,
		PASTEBOARD_KEY_TAG,
		SYNC_FIND_PASTEBOARD,
		DOUBLE_TAP_INTERVAL,
		COPY_FILES
	};
	
	int count = sizeof(optionKeys) / sizeof(NSString*);
	int i;
	
	NSMutableDictionary * clientOptions = [NSMutableDictionary dictionaryWithCapacity:count];
	for(i=0; i<count; i++) {
		NSString * optionKey = optionKeys[i];
		id value = [remoteHost optionForKey:optionKey];
		
		if([optionKey isEqualToString:REQUIRE_KEY]) {
			if(![[TPPreferencesManager sharedPreferencesManager] boolForPref:SYNC_MODIFIERS]) {
				value = @NO;
			}
		}
		
		if(value != nil) {
			[clientOptions setValue:value forKey:optionKey];
		}
	}
	
	return clientOptions;
}

- (void)_updateActivity
{
	UpdateSystemActivity(NetActivity);
}


#pragma mark -
#pragma mark Stop control

- (void)requestedStopControlWithInfoDict:(NSDictionary*)infoDict
{
	TPRemoteHost * controlledHost = [[self currentConnection] connectedHost];

	[[self currentConnection] sendMessage:[TPMessage messageWithType:TPControlStopMsgType]];
	
	TPEventsController * eventsController = [self eventsController];
	
	[self stopControlWithDisconnect:DISCONNECT_WHEN_STOP_CONTROL];
	
	/* Warp the mouse cursor to the exiting point */
	NSPoint mousePosition = [infoDict[TPMousePositionKey] pointValue];
	TPHotBorder * hotBorder = _hotBorders[[controlledHost identifier]];
	mousePosition = [hotBorder screenPointFromLocalPoint:mousePosition flipped:YES];
	
	if([hotBorder state] != TPHotBorderInactiveState) {
		[hotBorder deactivate];
		[eventsController warpMouseToPosition:mousePosition];
		[hotBorder delayedActivate];
	}
	else {
		[eventsController warpMouseToPosition:mousePosition];
	}
	
	[[self eventsController] cleanupGettingEvents];
}

- (void)stopControl
{
	[super stopControl];
	[[self eventsController] cleanupGettingEvents];
}

- (void)stopControlWithDisconnect:(BOOL)disconnect
{
#if DEBUG_GENERAL
	DebugLog(@"client: stopControl");
#endif
	
	if(_state == TPClientControllingState) {
		/* Deactivate events recorder */
		[[self eventsController] stopGettingEvents];
		
		/* Deactivate bezel */
		[[TPBezelController defaultController] hideBezel];
		
		/* Update status menu */
		[[TPStatusItemController defaultController] updateWithStatus:TPStatusIdle host:nil];
		
		/* Change state of controlled host */
		[[[self currentConnection] connectedHost] setHostState:TPHostPeeredOnlineState];
		
		/* Stop preventing sleep */
		[self _stopSleepPrevention];
		
		/* Play sound */
		if([[TPPreferencesManager sharedPreferencesManager] boolForPref:PLAY_SWITCH_SOUND]) {
			[self playSwitchSound];
		}
	}
	
	_state = TPClientIdleState;
	
	/* Update hot borders */
	[self updateTriggersAndShowVisualHint:NO];
	
	[super stopControlWithDisconnect:disconnect];
}

- (BOOL)isControlling
{
	return (_state == TPClientControllingState);
}


#pragma mark -
#pragma mark Sleep management

void TPSleepCallback(void * refCon, io_service_t service, natural_t messageType, void * messageArgument);

- (void)_startSleepPrevention
{
	if(_sleepService == IO_OBJECT_NULL) {
		_sleepService = IORegisterForSystemPower((__bridge void *)(self), &_sleepNotifyPortRef, TPSleepCallback, &_sleepNotifier);
		
		if(_sleepService == IO_OBJECT_NULL) {
			NSLog(@"IORegisterForSystemPower failed");
		}
		else {
			CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(_sleepNotifyPortRef), kCFRunLoopCommonModes);
		}
	}
}

- (void)_stopSleepPrevention
{
	if(_sleepService != IO_OBJECT_NULL) {
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(_sleepNotifyPortRef), kCFRunLoopCommonModes);
		IONotificationPortDestroy(_sleepNotifyPortRef);
		_sleepNotifyPortRef = NULL;
		
		IODeregisterForSystemPower(&_sleepNotifier);
		_sleepNotifier = IO_OBJECT_NULL;
		
		IOServiceClose(_sleepService);
		_sleepService = IO_OBJECT_NULL;
	}
}

void TPSleepCallback(void * refCon, io_service_t service, natural_t messageType, void * messageArgument)
{
	TPClientController * controller = (__bridge TPClientController*)refCon;
	io_connect_t sleepService = controller->_sleepService;
	
	switch(messageType) {
		case kIOMessageCanSystemSleep:
			DebugLog(@"Preventing sleep");
			IOCancelPowerChange(sleepService, (long)messageArgument);
			break;
		case kIOMessageSystemWillSleep:
			IOAllowPowerChange(sleepService, (long)messageArgument);
			break;
		default:
			break;
	}
}


#pragma mark -
#pragma mark Events listener

- (void)gotEventWithEventData:(NSData*)eventData
{
	//DebugLog(@"got event with event data (%d)", [eventData length]);
	[[self currentConnection] sendMessage:[TPMessage messageWithType:TPEventMsgType andData:eventData]];
}

- (void)gotEmergencyStopEvent
{
	[self stopControl];
}

- (BOOL)shouldStopWithEvent:(NSEvent*)event
{
	if([event type] == NSKeyDown) {
		TPRemoteHost * connectedHost = [[self currentConnection] connectedHost];
		PTKeyCombo * keyCombo = [connectedHost keyCombo];
		
		if(keyCombo != nil) {
			if(([keyCombo keyCode] == [event keyCode]) && ([keyCombo modifiers] == [PTKeyBroadcaster cocoaModifiersAsCarbonModifiers:[event modifierFlags]])) {
				[self stopControlWithDisconnect:DISCONNECT_WHEN_STOP_CONTROL];
				return YES;
			}
		}		
	}
	
	return NO;
}


#pragma mark -
#pragma mark Connection

- (void)connectionToServerSucceeded:(TPNetworkConnection*)connection infoDict:(NSDictionary*)infoDict
{
	[self sendStartControlRequestForConnection:connection withInfoDict:infoDict];
}

- (void)connectionToServerFailed:(TPRemoteHost*)host infoDict:(NSDictionary*)infoDict
{
	NSString * msgTitle = [NSString stringWithFormat:NSLocalizedString(@"Connection to \\U201C%@\\U201D failed.", @"Title for connection failure"), [host computerName]];
	NSAlert * alert = [NSAlert alertWithMessageText:msgTitle defaultButton:NSLocalizedString(@"OK", nil) alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"The server may be down, or an encryption problem may have occured. If encryption is enabled, please check that the certificate algorithms match.", nil)];
	[(TPMainController*)[NSApp delegate] presentAlert:alert];
	
	[self updateTriggersAndShowVisualHint:NO];
	
	_state = TPClientIdleState;
}

- (void)connection:(TPNetworkConnection*)connection receivedMessage:(TPMessage*)message
{
	TPMsgType type = [message msgType];
	
#if DEBUG_GENERAL
	DebugLog(@"master receive msg %ld", type);
#endif
	switch(type) {
		case TPControlSuccessMsgType:
			[self startControl];
			break;
		case TPControlFailureMsgType:
		{
			TPRemoteHost * controlledHost = [[self currentConnection] connectedHost];
			
			[controlledHost setHostState:TPHostSharedState];
			
			NSString * msgTitle = [NSString stringWithFormat:NSLocalizedString(@"Host \\U201C%@\\U201D rejected control.", @"Title for control failure"), [controlledHost computerName]];
			NSAlert * alert = [NSAlert alertWithMessageText:msgTitle defaultButton:NSLocalizedString(@"Yes", nil) alternateButton:NSLocalizedString(@"No", nil) otherButton:nil informativeTextWithFormat:NSLocalizedString(@"The host has probably removed this Mac from its trusted hosts list. Do you want to ask for trust again?", nil)];
			int result = [(TPMainController*)[NSApp delegate] presentAlert:alert];
			if(result == NSAlertDefaultReturn) {
				controlledHost = [[TPHostsManager defaultManager] hostWithIdentifier:[controlledHost identifier]];
				[[TPAuthenticationManager defaultManager] requestAuthenticationOnHost:controlledHost];
			}
			
			break;
		}
		case TPControlStopMsgType:
		{
			[self requestedStopControlWithInfoDict:[message infoDict]];
			break;
		}
		default:
			[super connection:connection receivedMessage:message];
	}
}

@end
