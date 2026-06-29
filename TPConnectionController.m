//
//  TPConnectionController.m
//  teleport
//
//  Created by JuL on Thu Jan 08 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPConnectionController.h"
#import "TPPreferencesManager.h"
#import "TPAuthenticationManager.h"
#import "TPClientController.h"
#import "TPEventsController.h"
#import "TPHotBorder.h"
#import "TPHostAnimationController.h"

#import "TPNetworkConnection.h"
#import "TPLocalHost.h"
#import "TPRemoteHost.h"
#import "TPMessage.h"

#import "TPHostsManager.h"
#import "TPTransfersManager.h"
#import "TPTransfer.h"
#import "TPPasteboardTransfer.h"
#import "TPFileTransfer.h"

NSString * TPScreenIndexKey = @"TPScreenIndex";
NSString * TPScreenPlacementKey = @"TPScreenPlacement";
NSString * TPMousePositionKey = @"TPMousePosition";
NSString * TPSwitchOptionsKey = @"TPSwitchOptions";
NSString * TPDraggedPathsKey = @"TPDraggedPaths";
NSString * TPDragImageKey = @"TPDragImage";
NSString * TPDragImageLocationKey = @"TPDragImageLocation";

@class TPClientController;

@interface TPConnectionController (Internal)

- (void)_preheatSwitchSoundIfNeeded;

@end

@implementation TPConnectionController

- (instancetype) init
{
	self = [super init];
	
	_currentConnection = nil;
	
	[self _preheatSwitchSoundIfNeeded];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_localHostDidChange:) name:TPHostDidUpdateNotification object:[TPLocalHost localHost]];
	
	return self;
}



#pragma mark -
#pragma mark Connection

- (void)setCurrentConnection:(TPNetworkConnection*)networkConnection
{
	if(_currentConnection != networkConnection) {
		[[TPTransfersManager manager] abortAllTransferRequests];
		[_currentConnection disconnect];
		
		_currentConnection = networkConnection;
		[_currentConnection setDelegate:self];
	}
}

- (TPNetworkConnection*)currentConnection
{
	return _currentConnection;
}

- (void)updateEventsController
{
	if(_currentConnection != nil) {
		TPEventsController * eventsController = [TPEventsController eventsControllerForRemoteHost:[_currentConnection connectedHost]];
		if(_eventsController != eventsController) {
			_eventsController = eventsController;
		}
	}
	else {
		_eventsController = nil;
	}
}

- (TPEventsController*)eventsController
{
	return _eventsController;
}

- (void)stopControl
{
	[self stopControlWithDisconnect:YES];
}

- (void)stopControlWithDisconnect:(BOOL)disconnect
{
	if(disconnect)
		[self setCurrentConnection:nil];
}

- (id)optionForRemoteHost:(TPRemoteHost*)remoteHost key:(NSString*)key
{
	return [remoteHost optionForKey:key];
}

- (void)_localHostDidChange:(NSNotification*)notification
{
	if(_currentConnection != nil && ([_currentConnection localHostCapabilities] != [[TPLocalHost localHost] capabilities])) {
		DebugLog(@"localHost did change: disconnect");
		[self stopControl];
	}
}


#pragma mark -
#pragma mark Hot border

- (TPHotBorder*)currentHotBorder
{
	return nil;
}

- (void)setupHotBorder:(TPHotBorder*)hotBorder forHost:(TPRemoteHost*)host
{
	[hotBorder bind:@"doubleTap" toObject:host withKeyPath:@"options.switchWithDoubleTap" options:nil];
	[hotBorder bind:@"acceptDrags" toObject:host withKeyPath:@"options.copyFiles" options:nil];
}

- (void)takeDownHotBorder:(TPHotBorder*)hotBorder
{
	[hotBorder unbind:@"doubleTap"];
	[hotBorder unbind:@"acceptDrags"];
}

- (BOOL)hotBorder:(TPHotBorder*)hotBorder firedAtLocation:(NSPoint)location withDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	if([[TPPreferencesManager sharedPreferencesManager] boolForPref:SHOW_SWITCH_ANIMATION]) {
		if([[TPLocalHost localHost] osVersion] >= TPHostOSVersion(5)) {
			TPRemoteHost * remoteHost = [[TPHostsManager defaultManager] hostWithIdentifier:[hotBorder identifier]];

			[[TPHostAnimationController controller] showFireAnimationForHost:remoteHost atPoint:[hotBorder screenPointFromLocalPoint:location flipped:NO] onScreen:[hotBorder screen] side:[hotBorder side]];
			
#if DEBUG_BUILD
			if([remoteHost isEqual:[TPLocalHost localHost]]) {
				[hotBorder activate];
			}
#endif
			return NO;
		}
		else {
			return YES;
		}
	}
	else {
		return NO;
	}
}

static NSString * _switchSoundPath = nil;
static NSSound * _switchSound = nil;
+ (NSSound*)_switchSound
{
	NSString * soundPath = [[TPPreferencesManager sharedPreferencesManager] valueForPref:SWITCH_SOUND_PATH];
	if(soundPath == nil || ![[NSFileManager defaultManager] fileExistsAtPath:soundPath]) {
		soundPath = [[NSBundle bundleForClass:[self class]] pathForSoundResource:@"switch-sound"];
	}
	
	if((_switchSoundPath == nil) || ![_switchSoundPath isEqualToString:soundPath]) {
		_switchSoundPath = [soundPath copy];
		
		_switchSound = [[NSSound alloc] initWithContentsOfFile:soundPath byReference:NO];
		
		if([_switchSound respondsToSelector:@selector(setVolume:)]) {
			[_switchSound setVolume:0.3]; // play it soft
		}
	}
	
	return _switchSound;
}

- (void)_preheatSwitchSoundIfNeeded
{
	if([[TPPreferencesManager sharedPreferencesManager] boolForPref:PLAY_SWITCH_SOUND]) {
		[[self class] _switchSound];
	}
}

- (void)playSwitchSound
{
	[[[self class] _switchSound] play];
}


#pragma mark -
#pragma mark Transfers

- (void)addDraggingInfo:(id<NSDraggingInfo>)draggingInfo toInfoDict:(NSMutableDictionary*)infoDict
{
	if(draggingInfo != nil && infoDict != nil) {
		NSPasteboard * dragPasteboard = [draggingInfo draggingPasteboard];
		
		if([[dragPasteboard types] containsObject:NSFilenamesPboardType]) {
			NSArray * draggedPaths = [dragPasteboard propertyListForType:NSFilenamesPboardType];
			NSImage * dragImage = [draggingInfo draggedImage];
			NSPoint dragImageLocation = [draggingInfo draggedImageLocation];
			
			if(dragImage != nil) {
				infoDict[TPDragImageKey] = dragImage;
				infoDict[TPDragImageLocationKey] = [NSValue valueWithPoint:dragImageLocation];
			}

			infoDict[TPDraggedPathsKey] = draggedPaths;
		}
	}
}

- (void)beginTransfersWithInfoDict:(NSDictionary*)infoDict
{
	/* First abort all pending transfer requests - real transfers will continue */
	[[TPTransfersManager manager] abortAllTransferRequests];
	
	TPRemoteHost * remoteHost = [[self currentConnection] connectedHost];
	
	BOOL sharePasteboard = [[self optionForRemoteHost:remoteHost key:SHARE_PASTEBOARD] boolValue];
	BOOL sharingPasteboardRequiresKey = [[self optionForRemoteHost:remoteHost key:REQUIRE_PASTEBOARD_KEY] boolValue];
	int sharingPastebardKeyTag = [[self optionForRemoteHost:remoteHost key:PASTEBOARD_KEY_TAG] intValue];
	
	/* Send pasteboard */
	if(sharePasteboard && [[TPEventsController defaultController] event:[NSApp currentEvent] hasRequiredKeyIfNeeded:sharingPasteboardRequiresKey withTag:sharingPastebardKeyTag]) {
		
		/* General pasteboard */
		TPOutgoingPasteboardTransfer * generalPasteboardTransfer = (TPOutgoingPasteboardTransfer*)[TPOutgoingPasteboardTransfer transfer];
		if([[self optionForRemoteHost:remoteHost key:LIMIT_PASTEBOARD_SIZE] boolValue]) {
			int maxKSize = [[self optionForRemoteHost:remoteHost key:MAX_PASTEBOARD_SIZE] intValue];
			unsigned long long maxSize = ((unsigned long long)maxKSize)*1024;
			[generalPasteboardTransfer setMaxSize:maxSize];
		}
		
		[[TPTransfersManager manager] beginTransfer:generalPasteboardTransfer usingConnection:[self currentConnection]];
		
		/* Optionnally the find pasteboard too */
		if([[self optionForRemoteHost:remoteHost key:SYNC_FIND_PASTEBOARD] boolValue]) {
			TPOutgoingPasteboardTransfer * findPasteboardTransfer = (TPOutgoingPasteboardTransfer*)[TPOutgoingPasteboardTransfer transfer];
			[findPasteboardTransfer setPasteboardName:NSFindPboard];
			[[TPTransfersManager manager] beginTransfer:findPasteboardTransfer usingConnection:[self currentConnection]];
		}
	}
	
	BOOL copyFiles = [[self optionForRemoteHost:remoteHost key:COPY_FILES] boolValue];
	
	/* Send files */
	if(copyFiles && [[TPLocalHost localHost] pairWithHost:remoteHost hasCapability:TPHostDragNDropCapability]) {
		NSArray * draggedFilePaths = infoDict[TPDraggedPathsKey];
		
		if(draggedFilePaths != nil && [draggedFilePaths count] > 0) {
			TPOutgoingFileTransfer * fileTransfer = (TPOutgoingFileTransfer*)[TPOutgoingFileTransfer transfer];
			[fileTransfer setFilePaths:draggedFilePaths dragImage:infoDict[TPDragImageKey] location:[infoDict[TPDragImageLocationKey] pointValue]];
			[[TPTransfersManager manager] beginTransfer:fileTransfer usingConnection:[self currentConnection]];
		}
	}
}


#pragma mark -
#pragma mark Messages handling

- (void)connection:(TPNetworkConnection*)connection receivedMessage:(TPMessage*)message
{
	TPMsgType type = [message msgType];
	
	switch(type) {
		case TPTransferRequestMsgType:
			[[TPTransfersManager manager] receiveTransferRequestWithInfoDict:[message infoDict] onConnection:connection isClient:[self isKindOfClass:[TPClientController class]]];
			break;
		case TPTransferSuccessMsgType:
			[[TPTransfersManager manager] startTransferWithUID:[message infoDict][TPTransferUIDKey] usingConnection:connection onPort:[[message infoDict][TPTransferPortKey] intValue]];
			break;
		case TPTransferFailureMsgType:
			[[TPTransfersManager manager] abortTransferWithUID:[message string]];
			break;
		default:
			DebugLog(@"unknown message type: %ld", type);
	}
}

- (void)connectionDisconnected:(TPNetworkConnection*)connection
{
	DebugLog(@"connection broken - disconnecting");
	[self stopControl];
}

@end
