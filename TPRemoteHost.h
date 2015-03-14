//
//  TPRemoteHost.h
//  teleport
//
//  Created by JuL on Fri Feb 27 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPHost.h"
#import "PTKeyCombo.h"

typedef NS_OPTIONS(NSUInteger, TPHostState) {
	TPHostUndefState			= 0,
	TPHostSharedState			= 1 << 0,
	TPHostPeeredOfflineState	= 1 << 1,
	TPHostPeeredOnlineState		= 1 << 2,
	TPHostControlledState		= 1 << 3,
	TPHostIncompatibleState		= 1 << 4,
	TPHostPeeringState			= 1 << 5,
	TPHostPeeredState			= TPHostPeeredOfflineState | TPHostPeeredOnlineState | TPHostControlledState | TPHostPeeringState,
	TPHostOnlineState			= TPHostSharedState | TPHostPeeredOnlineState | TPHostControlledState | TPHostIncompatibleState | TPHostPeeringState,
	TPHostDraggableState		= TPHostSharedState | TPHostPeeredOnlineState,
	TPHostAllStates				= 0xFFFF
} ;

@class TPOptionsProxy;

@interface TPRemoteHost : TPHost
{
	NSString * _identifier;
	SInt32 _osVersion;
	SecCertificateRef _certRef;
	NSString * _address;
	int _port;
	NSImage * _backgroundImage;
	NSArray * _screens;
	int _localScreenIndex;
	int _sharedScreenIndex;
	NSPoint _sharedScreenPosition;
	PTKeyCombo * _keyCombo;
	NSMutableDictionary * _customOptions;
	TPOptionsProxy * _optionsProxy;
	
	TPHostCapability _capabilities;
	TPHostState _state;
	TPHostState _previousHostState;
}

- (instancetype) initWithIdentifier:(NSString*)identifier address:(NSString*)address port:(int)port;

- (void)setIdentifier:(NSString*)identifier;
- (void)setOSVersion:(SInt32)osVersion;

/* Address */
- (void)setAddress:(NSString*)address;
@property (nonatomic) int port;

/* Certificate */
@property (nonatomic) SecCertificateRef certificate;
@property (nonatomic, readonly, copy) NSData *certificateData;
@property (nonatomic, getter=isCertified, readonly) BOOL certified;

/* Screens */
@property (nonatomic, copy) NSArray *screens;

@property (nonatomic, readonly, strong) NSScreen *localScreen;
@property (nonatomic) unsigned int localScreenIndex;

- (unsigned)sharedScreenIndex;
- (void)setSharedScreenIndex:(unsigned)sharedScreenIndex;

@property (nonatomic, readonly) NSRect hostRect;
@property (nonatomic, readonly) NSRect adjustedHostRect;
@property (nonatomic, readonly) NSRect fullHostRect;
- (void)setHostPosition:(NSPoint)position;

@property (nonatomic, copy) PTKeyCombo *keyCombo;

- (void)setBackgroundImage:(NSImage*)backgroundImage;

/* Capabilities */
- (void)setCapabilities:(TPHostCapability)capabilities;
- (void)setCapability:(TPHostCapability)capability isEnabled:(BOOL)enabled;

/* State */
@property (nonatomic) TPHostState hostState;
@property (nonatomic, readonly) TPHostState previousHostState;
- (BOOL)isInState:(TPHostState)hostState;

/* Custom options */
@property (nonatomic, readonly, strong) id options;
- (id)optionForKey:(NSString*)key;
- (void)setCustomOption:(id)option forKey:(NSString*)key;
@property (nonatomic, readonly, copy) NSArray *customizedOptions;
@property (nonatomic, readonly) BOOL hasCustomOptions;

- (void)resetCustomOptions;
- (void)makeDefaultOptions;

@end

@interface NSArray (TPRemoteHostAdditions)

- (NSArray*)hostsWithState:(TPHostState)state;

@end
