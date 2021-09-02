//
//  TPPreferencesManager.h
//  teleport
//
//  Created by JuL on 11/08/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define CURRENT_PREFS_VERSION 7
#define PREFS_VERSION @"prefsVersion"
#define SHARE_PASTEBOARD @"sharePasteboard"
#define SYNC_LOCK_STATUS @"syncLockStatus"
#define SYNC_SLEEP_STATUS @"syncSleepStatus"
#define ALLOW_CONTROL @"allowControl"
#define REQUIRE_KEY @"requireKey"
#define DELAYED_SWITCH @"delayedSwitch"
#define SWITCH_DELAY @"switchDelay"
#define SWITCH_WITH_DOUBLE_TAP @"switchWithDoubleTap"
#define LIMIT_PASTEBOARD_SIZE @"limitPasteboardSize"
#define MAX_PASTEBOARD_SIZE @"maxPasteboardSize"
#define AUTOCHECK_VERSION @"autocheckVersion"
#define TRUST_REQUEST_BEHAVIOR @"trustRequestBehavior"
#define ENABLED_ENCRYPTION @"enableEncryption"
#define SWITCH_KEY_TAG @"switchKeyTag"
#define COPY_FILES @"copyFiles"
#define REQUIRE_PASTEBOARD_KEY @"requirePasteboardKey"
#define PASTEBOARD_KEY_TAG @"pasteboardKeyTag"
#define INHIBITION_PERIOD @"hotBorderActivationDelay"
#define SYNC_FIND_PASTEBOARD @"syncFindPasteboard"
#define WARNED_ABOUT_ACCESSIBILITY @"warnedAboutAccessibility"
#define WAKE_ON_LAN @"wakeOnLAN"
#define HIDE_CONTROL_BEZEL @"hideControlBezel"
#define TRUST_LOCAL_CERTIFICATE @"trustLocalCertificate"
#define CERTIFICATE_IDENTIFIER @"certificateIdentifier"
#define SHARED_SCREEN_INDEX @"sharedScreenIndex"
#define SHOW_SWITCH_ANIMATION @"showSwitchAnimation"
#define DOUBLE_TAP_INTERVAL @"doubleTapInterval"
#define SHOW_TEXTUAL_STATUS @"showTextualStatus"
#define TIGER_BEHAVIOR @"tigerBehavior"
#define ADD_TO_LOGIN_ITEMS @"addToLoginItems"
#define DISCONNECT_ON_NETWORK_CONFIG_CHANGE @"disconnectOnNetworkConfigChange"
#define WRAP_ON_STOP_CONTROL @"wrapOnStopControl"
#define PLAY_SWITCH_SOUND @"playSwitchSound"
#define SWITCH_SOUND_PATH @"switchSoundPath"
#define APPLICATIONS_DISABLING_TELEPORT @"appIdentifiersDisablingTeleport"
#define SYNC_MODIFIERS @"syncModifiers"

#define COMMAND_PORT @"commandPort"
#define TRANSFER_PORT @"transferPort"

#define COMMAND_KEY_TAG 20
#define ALT_KEY_TAG 19
#define CTRL_KEY_TAG 18
#define SHIFT_KEY_TAG 17
#define CAPSLOCK_KEY_TAG 16

enum {
	TRUST_REQUEST_ASK		= 0,
	TRUST_REQUEST_REJECT	= 1,
	TRUST_REQUEST_ACCEPT 	= 2
};

extern NSString * TPPreferencesDidUpgradeNotification;
extern NSString * TPDefaultsDidChangeNotification;

extern NSString * TPPreferencesPreviousVersionKey;

@interface NSObject (PreferencesAdditions)

- (void)bind:(NSString*)binding toPref:(NSString*)prefKey;

@end

@interface TPPreferencesManager : NSObject
{
	BOOL _isLocal;
}

+ (TPPreferencesManager*)sharedPreferencesManager;

@property (nonatomic, getter=isLocal, readonly) BOOL local;

- (BOOL)boolForPref:(NSString*)pref;
- (int)intForPref:(NSString*)pref;
- (float)floatForPref:(NSString*)pref;
- (id)valueForPref:(NSString*)pref;

- (int)portForPref:(NSString*)pref;

- (BOOL)event:(NSEvent*)event hasRequiredKeyIfNeeded:(NSString*)boolPref withTag:(NSString*)tagPref;

@end
