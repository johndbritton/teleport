//
//  TPServerController.m
//  Teleport
//
//  Created by JuL on Thu Dec 04 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPServerController.h"
#import "TPMainController.h"
#import "TPClientController.h"
#import "TPAuthenticationManager.h"
#import "TPEventsController.h"
#import "TPNetworkConnection.h"
#import "TPTransfersManager.h"
#import "TPHotBorder.h"
#import "TPMessage.h"
#import "TPLocalHost.h"
#import "TPRemoteHost.h"
#import "TPStatusItemController.h"
#import "TPPreferencesManager.h"
#import "TPConnectionsManager.h"
#import "TPTCPSecureSocket.h"
#import "TPHostsManager.h"

#import "TPBonjourController.h"
#import "TPPasteboardTransfer.h"
#import "TPBackgroundImageTransfer.h"

static TPServerController * _defaultServerController = nil;

@implementation TPServerController

+ (TPServerController*)defaultController
{
	if(_defaultServerController == nil)
		_defaultServerController = [[TPServerController alloc] init];
	
	return _defaultServerController;
}

- (instancetype) init
{
	self = [super init];
	
	_state = TPServerIdleState;
	
	[self bind:@"allowControl" toPref:ALLOW_CONTROL];
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(connectionDisconnected:) name:NSWorkspaceSessionDidResignActiveNotification object:nil];
	
	return self;
}

- (void)dealloc
{
	if(_state == TPServerSharedState)
		[self stopSharing];
	else if(_state == TPServerControlledState)
		[self stopControl];
	
	
}


#pragma mark -
#pragma mark Sharing

- (void)startSharing
{
#if DEBUG_GENERAL
	DebugLog(@"server: startWaiting");
#endif
	int port = [[TPPreferencesManager sharedPreferencesManager] portForPref:COMMAND_PORT];
	
	if([[TPConnectionsManager manager] startListeningWithDelegate:self onPort:&port]) {
		DebugLog(@"listening on port %d", port);
		[[TPBonjourController defaultController] publishWithPort:port];
	}
}

- (void)stopSharing
{
#if DEBUG_GENERAL
	DebugLog(@"server: stopWaiting");
#endif
	
	[self stopControl];
	[[TPBonjourController defaultController] unpublish];
	[[TPConnectionsManager manager] stopListening];
}


#pragma mark -
#pragma mark Hot border

- (TPHotBorder*)currentHotBorder
{
	return _clientHotBorder;
}

- (void)setupHotBorder:(TPHotBorder*)hotBorder forHost:(TPRemoteHost*)host
{
	[hotBorder setDoubleTap:[[self optionForRemoteHost:host key:SWITCH_WITH_DOUBLE_TAP] boolValue]];
	[hotBorder setAcceptDrags:[[self optionForRemoteHost:host key:COPY_FILES] boolValue]];
}

- (float)hotBorderSwitchDelay:(TPHotBorder*)hotBorder
{
	if(![[self optionForRemoteHost:nil key:DELAYED_SWITCH] boolValue]) {
		return 0.0;
	}
	else {
		return [[self optionForRemoteHost:nil key:SWITCH_DELAY] floatValue];
	}
}

- (BOOL)hotBorder:(TPHotBorder*)hotBorder canFireWithEvent:(NSEvent*)event
{
	NSAssert(hotBorder == _clientHotBorder, @"Hot border should be the client hot border");
	BOOL requireKey = [[self optionForRemoteHost:nil key:REQUIRE_KEY] boolValue];
	int keyTag = [[self optionForRemoteHost:nil key:SWITCH_KEY_TAG] intValue];
	return [[self eventsController] event:event hasRequiredKeyIfNeeded:requireKey withTag:keyTag];
}

- (BOOL)hotBorder:(TPHotBorder*)hotBorder firedAtLocation:(NSPoint)location withDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	//DebugLog(@"loc=%d", location);
	[self requestStopControlAtLocation:location withDraggingInfo:draggingInfo];
	
	return [super hotBorder:hotBorder firedAtLocation:location withDraggingInfo:draggingInfo];
}


#pragma mark -
#pragma mark Switch options

- (void)setSwitchOptions:(NSDictionary*)switchOptions
{
	if(switchOptions != _switchOptions) {
		_switchOptions = switchOptions;
	}
}

- (id)optionForRemoteHost:(TPRemoteHost*)remoteHost key:(NSString*)key
{
	id option = (_switchOptions == nil) ? nil : _switchOptions[key];
	if(option == nil) {
		option = [[TPPreferencesManager sharedPreferencesManager] valueForPref:key];
	}
	return option;
}


#pragma mark -
#pragma mark Start control

- (void)requestedStartControlByHost:(TPRemoteHost*)host onConnection:(TPNetworkConnection*)connection withInfoDict:(NSDictionary*)infoDict
{
#if DEBUG_GENERAL
	DebugLog(@"server: startControl");
#endif
	
	BOOL connectionIsCurrent = (connection == [self currentConnection]);
	
	/* Reject if host is not controllable */
	if(![(TPMainController*)[NSApp delegate] canBeControlledByHostWithIdentifier:[host identifier]]) {
		[connection sendMessage:[TPMessage messageWithType:TPControlFailureMsgType
											   andInfoDict:@{@"reason": NSLocalizedString(@"Host not controllable.", @"Reason for control failure")}]];
		if(connectionIsCurrent)
			[self setCurrentConnection:nil];
		else
			;
		DebugLog(@"Rejecting control: host not controllable");
		return;
	}
	
	/* Reject if client not trusted */
	if(![[TPAuthenticationManager defaultManager] isHostTrusted:host]) {
		[connection sendMessage:[TPMessage messageWithType:TPControlFailureMsgType
											   andInfoDict:@{@"reason": NSLocalizedString(@"Host not trusted.", @"Reason for control failure")}]];
		if(connectionIsCurrent)
			[self setCurrentConnection:nil];
		else
			;
		DebugLog(@"Rejecting control: remote host not trusted");
		return;
	}
	
	/* Accept control */
	[connection sendMessage:[TPMessage messageWithType:TPControlSuccessMsgType]];

	if(!connectionIsCurrent) {
		[self setCurrentConnection:connection];
	}
	
	[self updateEventsController];
	
	[self startControlWithInfoDict:infoDict];
}

- (void)startControlWithInfoDict:(NSDictionary*)infoDict
{
#if DEBUG_GENERAL
	DebugLog(@"server: startPlaying");
#endif

	_state = TPServerControlledState;
	
	TPRemoteHost * host = [[self currentConnection] connectedHost];
	
	/* Update status menu */
	[[TPStatusItemController defaultController] updateWithStatus:TPStatusControlled host:host];

	/* Remove hot borders for controlling */
	[[TPClientController defaultController] updateTriggersAndShowVisualHint:NO];
	
	/* Setup the hotborder for the return */
	NSRect screenPlacement = [infoDict[TPScreenPlacementKey] rectValue];
	int sharedScreenIndex = [infoDict[TPScreenIndexKey] intValue];
	NSRect sharedScreenFrame = [[[TPLocalHost localHost] screenAtIndex:sharedScreenIndex] frame];
	screenPlacement.origin.x += NSMinX(sharedScreenFrame);
	screenPlacement.origin.y += NSMinY(sharedScreenFrame);
	
	_clientHotBorder = [[TPHotBorder alloc] initWithRepresentingRect:screenPlacement inRect:sharedScreenFrame];
	[self setupHotBorder:_clientHotBorder forHost:host];
	[_clientHotBorder setDelegate:self];
	[_clientHotBorder delayedActivate];
	
	[[self eventsController] startPostingEvents];
	
	/* Move mouse */
	BOOL shouldWarp = NO;
	NSPoint mousePosition = [infoDict[TPMousePositionKey] pointValue];
	if(mousePosition.x >= 0.0 && mousePosition.y >= 0.0) {
		shouldWarp = YES;
		DebugLog(@"mousePosition=%@", NSStringFromPoint(mousePosition));
		mousePosition = [_clientHotBorder screenPointFromLocalPoint:mousePosition flipped:YES];
	}
	
	if([_clientHotBorder state] != TPHotBorderInactiveState) {
		[_clientHotBorder deactivate];
		if(shouldWarp) {
			[[self eventsController] warpMouseToPosition:mousePosition];
		}
		[_clientHotBorder delayedActivate];
	}
	else if(shouldWarp) {
		[[self eventsController] warpMouseToPosition:mousePosition];
	}
	
	/* Get switch options */
	[self setSwitchOptions:infoDict[TPSwitchOptionsKey]];
	
	/* Send the background image (low priority transfer) */
	if([[TPLocalHost localHost] hasCustomBackgroundImage])
		[[TPTransfersManager manager] beginTransfer:[TPOutgoingBackgroundImageTransfer transfer] usingConnection:[self currentConnection]];
	
	/* Wake up display */
	[[TPLocalHost localHost] wakeUpScreen];
	
	io_registry_entry_t entry = IORegistryEntryFromPath(kIOMasterPortDefault,
														"IOService:/IOResources/IODisplayWrangler");
	if (entry != MACH_PORT_NULL) {
		IORegistryEntrySetCFProperty(entry, CFSTR("IORequestIdle"), kCFBooleanFalse);
		IOObjectRelease(entry);
	}
	
//	[eventsPlayer releaseAllKeys];
	
	DebugLog(@"hotBorderRect=%@", NSStringFromRect([_clientHotBorder hotRect]));
}


#pragma mark -
#pragma mark Stop control

- (void)requestStopControlAtLocation:(NSPoint)location withDraggingInfo:(id<NSDraggingInfo>)draggingInfo
{
	NSMutableDictionary * infoDict = [NSMutableDictionary dictionaryWithObject:[NSData dataWithPoint:location] forKey:TPMousePositionKey];
	[self addDraggingInfo:draggingInfo toInfoDict:infoDict];
	[self beginTransfersWithInfoDict:infoDict];

	TPMessage * message = [TPMessage messageWithType:TPControlStopMsgType
										 andInfoDict:infoDict];
	
	[[self currentConnection] sendMessage:message];	
	
	/* Do the fake mouse up */
	if(draggingInfo != nil)
		[[TPEventsController defaultController] mouseUpAtPosition:[NSEvent mouseLocation]];
}

- (void)stopControlWithDisconnect:(BOOL)disconnect
{
#if DEBUG_GENERAL
	DebugLog(@"server: stopPlaying");
#endif

	[super stopControlWithDisconnect:disconnect];
	
	if(_state == TPServerControlledState) {
		_state = TPServerSharedState;
		
		if([[TPPreferencesManager sharedPreferencesManager] boolForPref:WRAP_ON_STOP_CONTROL])
			[[self eventsController] warpMouseToCenter];
		
		[[self eventsController] stopPostingEvents];
		
		[self takeDownHotBorder:_clientHotBorder];
		_clientHotBorder = nil;
		
		/* Update status menu */
		[[TPStatusItemController defaultController] updateWithStatus:TPStatusIdle host:nil];
		
		/* Re-add hot borders for controlling */
		[[TPClientController defaultController] updateTriggersAndShowVisualHint:NO];
	}
}


#pragma mark -
#pragma mark Network connection delegate

- (void)connectionFromClientAccepted:(TPNetworkConnection*)connection
{
	[connection setDelegate:self];
}

- (void)connection:(TPNetworkConnection*)connection receivedMessage:(TPMessage*)message
{
	TPMsgType type = [message msgType];

#if DEBUG_GENERAL
	DebugLog(@"slave receive msg %ld", type);
#endif

	switch(type) {
		case TPControlRequestMsgType:
		{
			[self requestedStartControlByHost:[connection connectedHost] onConnection:connection withInfoDict:[message infoDict]];
			break;
		}
		case TPControlStopMsgType:
		{
			[self stopControlWithDisconnect:DISCONNECT_WHEN_STOP_CONTROL];
			break;
		}
		case TPAuthenticationRequestMsgType:
		{
			[[TPAuthenticationManager defaultManager] authenticationRequestedFromHost:[connection connectedHost] onConnection:connection];
			break;
		}
		case TPEventMsgType:
			[[self eventsController] postEventWithEventData:[message data]];
			break;
		default:
			[super connection:connection receivedMessage:message];
	}
}




#pragma mark -
#pragma mark Setters and getters

- (void)setAllowControl:(BOOL)allowControl
{
	if(allowControl && _state != TPServerSharedState) {
		[self startSharing];
		_state = TPServerSharedState;
	}
	else if(!allowControl && _state != TPServerIdleState) {
		[self stopSharing];
		_state = TPServerIdleState;
	}
}

- (BOOL)allowControl
{
	return (_state != TPServerIdleState);
}

- (BOOL)isControlled
{
	return (_state == TPServerControlledState);
}

@end
