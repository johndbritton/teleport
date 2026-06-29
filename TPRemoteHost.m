//
//  TPRemoteHost.m
//  teleport
//
//  Created by JuL on Fri Feb 27 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPRemoteHost.h"
#import "TPHostSnapping.h"
#import "TPPreferencesManager.h"
#import "TPLocalHost.h"

NSString * TPRemoteHostAddressKey = @"address";
NSString * TPRemoteHostScreensKey = @"screens";
NSString * TPRemoteHostSharedScreenIndexKey = @"sharedScreenIndex";
NSString * TPRemoteHostSharedScreenPositionKey = @"sharedScreenPosition";
NSString * TPRemoteHostLocalScreenIndexKey = @"localScreenIndex";
NSString * TPRemoteHostCertificateKey = @"certificate";
NSString * TPRemoteHostStateKey = @"state";
NSString * TPRemoteHostKeyComboKey = @"keyCombo";
NSString * TPRemoteHostCustomOptionsKey = @"customOptions";

@interface TPOptionsProxy : NSObject
{
	TPRemoteHost * _remoteHost;
}

- (instancetype) initWithRemoteHost:(TPRemoteHost*)remoteHost NS_DESIGNATED_INITIALIZER;

- (void)resetCustomOptions;

@end

@implementation TPOptionsProxy

- (instancetype) initWithRemoteHost:(TPRemoteHost*)remoteHost
{
	self = [super init];
	
	_remoteHost = remoteHost;
	
	return self;
}

- (id)valueForKey:(NSString*)key
{
	return [_remoteHost optionForKey:key];
}

- (void)setValue:(id)value forKey:(NSString*)key
{
	[self willChangeValueForKey:key];
	[_remoteHost setCustomOption:value forKey:key];
	[self didChangeValueForKey:key];
}

- (void)resetCustomOptions
{
	NSArray * customizedOptions = [_remoteHost customizedOptions];
	NSEnumerator * optionsEnum = [customizedOptions objectEnumerator];
	NSString * key;
	while((key = [optionsEnum nextObject]) != nil) {
		[self willChangeValueForKey:key];
		[_remoteHost setCustomOption:nil forKey:key];
		[self didChangeValueForKey:key];
	}
}

@end

@implementation TPRemoteHost

- (instancetype) init
{
	self = [super init];
	
	_state = TPHostUndefState;
	_previousHostState = TPHostUndefState;
	_localScreenIndex = -1;
	_certRef = NULL;
	
	return self;
}

- (instancetype) initWithIdentifier:(NSString*)identifier address:(NSString*)address port:(int)port
{
	self = [self init];
	
	_identifier = [identifier copy];
	_address = [address copy];
	_port = port;
	_computerName = [identifier copy];
	
	return self;
}

- (instancetype) initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	
	_identifier = [[coder decodeObjectForKey:TPHostIdentifierKey] copy];
	_address = [[coder decodeObjectForKey:TPRemoteHostAddressKey] copy];
	
	if([coder containsValueForKey:TPRemoteHostScreensKey])
		_screens = [TPScreen screensFromString:[coder decodeObjectForKey:TPRemoteHostScreensKey]];
	else
		_screens = nil;

	if([coder containsValueForKey:TPRemoteHostSharedScreenIndexKey])
		_sharedScreenIndex = [coder decodeIntForKey:TPRemoteHostSharedScreenIndexKey];
	else
		_sharedScreenIndex = -1;
	
	if([coder containsValueForKey:TPRemoteHostSharedScreenPositionKey])
		_sharedScreenPosition = [coder decodePointForKey:TPRemoteHostSharedScreenPositionKey];
	else
		_sharedScreenPosition = NSZeroPoint;
	
	if([coder containsValueForKey:TPRemoteHostLocalScreenIndexKey])
		_localScreenIndex = [coder decodeIntForKey:TPRemoteHostLocalScreenIndexKey];
	else
		_localScreenIndex = -1;
	
	if([coder containsValueForKey:TPHostBackgroundImageDataKey]) {
#if LEGACY_BUILD
		unsigned length = 0;
#else
		NSUInteger length = 0;
#endif
		const uint8_t * bytes = [coder decodeBytesForKey:TPHostBackgroundImageDataKey returnedLength:&length];
		NSData * backgroundImageData = [NSData dataWithBytesNoCopy:(void*)bytes length:length freeWhenDone:NO];
		if(backgroundImageData != nil)
			_backgroundImage = [[NSImage alloc] initWithData:backgroundImageData];
		else
			_backgroundImage = nil;
	}
	else
		_backgroundImage = nil;
	
	if([coder containsValueForKey:TPRemoteHostCertificateKey]) {
		OSErr err;
		CSSM_DATA cssmCertData;
#if LEGACY_BUILD
		unsigned length = 0;
#else
		NSUInteger length = 0;
#endif
		cssmCertData.Data = (uint8 *)[coder decodeBytesForKey:TPRemoteHostCertificateKey returnedLength:&length];
		cssmCertData.Length = length;
		
		if((err = SecCertificateCreateFromData(&cssmCertData, CSSM_CERT_UNKNOWN, CSSM_CERT_ENCODING_UNKNOWN, &_certRef)) != noErr)
			NSLog(@"Error reading certificate for %@: %d", self, err);
	}
	
	_capabilities = [coder decodeIntForKey:TPHostCapabilitiesKey];
	_osVersion = [coder decodeInt32ForKey:TPHostOSVersionKey];
	
	if([coder containsValueForKey:TPRemoteHostStateKey])
		_state = [coder decodeIntForKey:TPRemoteHostStateKey];
	else
		_state = -1;
	
	if([coder containsValueForKey:TPRemoteHostKeyComboKey]) {
		_keyCombo = [[PTKeyCombo alloc] initWithPlistRepresentation:[coder decodeObjectForKey:TPRemoteHostKeyComboKey]];
	}
	
	if([coder containsValueForKey:TPRemoteHostCustomOptionsKey]) {
		_customOptions = [[coder decodeObjectForKey:TPRemoteHostCustomOptionsKey] mutableCopy];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	
	[coder encodeObject:_address forKey:TPRemoteHostAddressKey];
	[coder encodeObject:[TPScreen stringFromScreens:_screens] forKey:TPRemoteHostScreensKey];
	[coder encodeInt:_sharedScreenIndex forKey:TPRemoteHostSharedScreenIndexKey];
	[coder encodePoint:_sharedScreenPosition forKey:TPRemoteHostSharedScreenPositionKey];
	[coder encodeInt:_localScreenIndex forKey:TPRemoteHostLocalScreenIndexKey];

#if 1
	if([self hasCustomBackgroundImage]) {
		NSData * backgroundImageData = [self backgroundImageData];
		if(backgroundImageData != nil)
			[coder encodeBytes:[backgroundImageData bytes] length:[backgroundImageData length] forKey:TPHostBackgroundImageDataKey];
	}
#endif
	
	if(_certRef != NULL) {
		OSErr err;
		CSSM_DATA cssmCertData;
		if((err = SecCertificateGetData(_certRef, &cssmCertData)) != noErr)
			NSLog(@"Error writing certificate for %@: %d", self, err);
		else
			[coder encodeBytes:cssmCertData.Data length:cssmCertData.Length forKey:TPRemoteHostCertificateKey];
	}
	
	[coder encodeInt:_state forKey:TPRemoteHostStateKey];
	
	if((_keyCombo != nil) && ![_keyCombo isClearCombo] && [_keyCombo isValidHotKeyCombo]) {
		[coder encodeObject:[_keyCombo plistRepresentation] forKey:TPRemoteHostKeyComboKey];
	}
	
	if(_customOptions != nil) {
		[coder encodeObject:_customOptions forKey:TPRemoteHostCustomOptionsKey];
	}
}

- copyWithZone:(NSZone*)zone
{
	TPRemoteHost * copy = [[TPRemoteHost alloc] initWithIdentifier:[self identifier] address:_address port:_port];
	copy->_keyCombo = [_keyCombo copy];
	copy->_customOptions = [_customOptions mutableCopy];
	return copy;
}

- (void)dealloc
{
	if(_certRef != NULL)
		CFRelease(_certRef);
}

- (NSString*)identifier
{
	return _identifier;
}

- (void)setIdentifier:(NSString*)identifier
{
	if(identifier != _identifier) {
		_identifier = identifier;
	}
}

- (SInt32)osVersion
{
	return _osVersion;
}

- (void)setOSVersion:(SInt32)osVersion
{
	_osVersion = osVersion;
}


#pragma mark -
#pragma mark Address

- (NSString*)address
{
	return _address;
}

- (void)setAddress:(NSString*)address
{
	if(address != _address) {
		_address = [address copy];
	}
}

- (void)setPort:(int)port
{
	_port = port;
	[self notifyChange];
}

- (int)port
{
	return _port;
}


#pragma mark -
#pragma mark Certificate

- (SecCertificateRef)certificate
{
	return _certRef;
}

- (NSData*)certificateData
{
	if(_certRef == NULL)
		return nil;
	else {
		OSErr err;
		CSSM_DATA cssmCertData;
		if((err = SecCertificateGetData(_certRef, &cssmCertData)) != noErr) {
			NSLog(@"Error writing certificate for %@: %d", self, err);
			return nil;
		}
		else
			return [NSData dataWithBytesNoCopy:cssmCertData.Data length:cssmCertData.Length freeWhenDone:NO];
	}
}

- (void)setCertificate:(SecCertificateRef)certRef
{
	if(_certRef != NULL)
		CFRelease(_certRef);
	_certRef = certRef;
	if(_certRef != NULL)
		CFRetain(_certRef);
}

- (BOOL)isCertified
{
	return (_certRef != NULL);
}


#pragma mark -
#pragma mark Screen

- (NSArray*)screens
{
	return _screens;
}

- (void)setScreens:(NSArray*)screens
{
	if(screens != _screens) {
		_screens = screens;
	}
}


//- (NSSize)screenSize
//{
//	return _hostRect.size;
//}
//
//- (void)setScreenSize:(NSSize)screenSize
//{
//	if(!NSEqualSizes(screenSize, _hostRect.size)) {
////		NSRect localScreenRect = [[self localScreen] frame];
////		float deltaX = 0.0;
////		float deltaY = 0.0;
////		
////		if(_hostRect.origin.x == (localScreenRect.origin.x + localScreenRect.size.width)) { // on the right
////																							//deltaX = 0.0;//(_hostRect.size.width - screenSize.width)/2.0;
////		}
////		else if(_hostRect.origin.x == (localScreenRect.origin.x - _hostRect.size.width)) { // on the left
////			deltaX = (_hostRect.size.width - screenSize.width);
////		}
////		else if(_hostRect.origin.y == (localScreenRect.origin.y + localScreenRect.size.height)) { // on the top
////																								  //deltaX = 0.0;(_hostRect.size.width - screenSize.width)/2.0;
////		}
////		else if(_hostRect.origin.y == (localScreenRect.origin.y - _hostRect.size.height)) { // on the bottom
////			deltaY = (_hostRect.size.height - screenSize.height);
////		}
//		
//		_hostRect.size = screenSize;
//		
//		[self notifyChange];
//	}
//}

- (NSScreen*)localScreen
{
	return [[TPLocalHost localHost] screenAtIndex:_localScreenIndex];
}

- (unsigned)localScreenIndex
{
	return _localScreenIndex;
}

- (void)setLocalScreenIndex:(unsigned)inLocalScreenIndex
{
	if(_localScreenIndex != inLocalScreenIndex) {
		_localScreenIndex = inLocalScreenIndex;
		[self notifyChange];
	}
}

- (unsigned)sharedScreenIndex
{
	return _sharedScreenIndex;
}

- (void)setSharedScreenIndex:(unsigned)sharedScreenIndex
{
	_sharedScreenIndex = sharedScreenIndex;
}

- (NSRect)hostRect
{
	NSArray * screens = [self screens];
	if([screens count] > 0 && _sharedScreenIndex < [screens count]) {
		NSRect hostRect;
		NSScreen * screen = screens[_sharedScreenIndex];
		hostRect = [screen frame];
		hostRect.origin = _sharedScreenPosition;
		return hostRect;
	}
	else {
		return NSZeroRect;
	}
}

- (NSRect)fullHostRect
{
	NSRect fullHostRect = NSZeroRect;
	NSArray * screens = [self screens];
	NSEnumerator * screenEnum = [screens objectEnumerator];
	NSScreen * screen;
	while((screen = [screenEnum nextObject]) != nil) {
		NSRect screenRect = [screen frame];
		fullHostRect = NSUnionRect(fullHostRect, screenRect);
	}
	return fullHostRect;
}

- (void)setHostPosition:(NSPoint)position
{
	_sharedScreenPosition = position;
	[self notifyChange];
}

- (NSRect)adjustedHostRect
{
	NSRect hostRect = [self hostRect];
	NSRect localRect = [[self localScreen] frame];
	NSRect adjustedHostRect;
	TPGluedRect(&adjustedHostRect, NULL, localRect, hostRect, TPUndefSide);
	return adjustedHostRect;
}

- (PTKeyCombo*)keyCombo
{
	return _keyCombo;
}

- (void)setKeyCombo:(PTKeyCombo*)keyCombo
{
	
	if(keyCombo == nil) {
		_keyCombo = nil;
	}
	else {
		_keyCombo = [[PTKeyCombo alloc] initWithPlistRepresentation:[keyCombo plistRepresentation]];
	}
	
	[self notifyChange];
}


#pragma mark -
#pragma mark Background image

- (void)setBackgroundImage:(NSImage*)backgroundImage
{
	if(backgroundImage != _backgroundImage) {
		_backgroundImage = backgroundImage;
		
		[self notifyChange];
	}
}

- (NSImage*)backgroundImage
{
	if(_backgroundImage != nil)
		return _backgroundImage;
	else
		return [self defaultBackgroundImage];
}

- (BOOL)hasCustomBackgroundImage
{
	return (_backgroundImage != nil);
}


#pragma mark -
#pragma mark Capabilities

- (TPHostCapability)capabilities
{
	return _capabilities;
}

- (BOOL)hasCapability:(TPHostCapability)capability
{
	return ((_capabilities & capability) != 0);
}

- (void)setCapabilities:(TPHostCapability)capabilities
{
	if(capabilities != _capabilities) {
		_capabilities = capabilities;
		[self notifyChange];
	}
}

- (void)setCapability:(TPHostCapability)capability isEnabled:(BOOL)enabled
{
	if(enabled)
		_capabilities |= capability;
	else
		_capabilities &= ~capability;

	[self notifyChange];
}


#pragma mark -
#pragma mark State

- (TPHostState)hostState
{
	return _state;
}

- (TPHostState)previousHostState
{
	return _previousHostState;
}

- (BOOL)isInState:(TPHostState)hostState
{
	return ((_state & hostState) != 0);
}

- (void)setHostState:(TPHostState)state
{
//	DebugLog(@"changing state of host %p (%@) from %d to %d", self, _identifier, _state, state);
	if(state != _state) {
		_previousHostState = _state;
		_state = state;
		[self notifyChange];
	}
}


#pragma mark -
#pragma mark Custom options

- (id)options
{
	if(_optionsProxy == nil) {
		_optionsProxy = [[TPOptionsProxy alloc] initWithRemoteHost:self];
	}
	
	return _optionsProxy;
}

- (id)optionForKey:(NSString*)key
{
	id option = (_customOptions == nil) ? nil : _customOptions[key];
	if(option == nil) {
		option = [[TPPreferencesManager sharedPreferencesManager] valueForPref:key];
	}
	return option;
}

- (void)setCustomOption:(id)option forKey:(NSString*)key
{
	[self willChangeValueForKey:@"hasCustomOptions"];

	if(_customOptions == nil && option != nil) {
		_customOptions = [[NSMutableDictionary alloc] init];
	}
	
	if(_customOptions != nil) {
		if(option == nil) {
			[_customOptions removeObjectForKey:key];
		}
		else {
			if([option isEqual:[[TPPreferencesManager sharedPreferencesManager] valueForPref:key]]) {
				[_customOptions removeObjectForKey:key];
			}
			else {
				_customOptions[key] = option;
			}
		}
		
		if([_customOptions count] == 0) {
			_customOptions = nil;
		}
	}
	
	[self didChangeValueForKey:@"hasCustomOptions"];
}

- (NSArray*)customizedOptions
{
	return (_customOptions == nil) ? @[] : [_customOptions allKeys];
}

- (BOOL)hasCustomOptions
{
	return (_customOptions != nil);
}

- (void)resetCustomOptions
{
	[self willChangeValueForKey:@"hasCustomOptions"];
	
	[[self options] resetCustomOptions];
	
	_customOptions = nil;
	
	[self didChangeValueForKey:@"hasCustomOptions"];
}

- (void)makeDefaultOptions
{
	[self willChangeValueForKey:@"hasCustomOptions"];

	NSEnumerator * optionsEnum = [_customOptions keyEnumerator];
	NSString * key;
	while((key = [optionsEnum nextObject]) != nil) {
		id value = [self optionForKey:key];
		[[TPPreferencesManager sharedPreferencesManager] setValue:value forKey:key];
	}
	
	_customOptions = nil;
	
	[self didChangeValueForKey:@"hasCustomOptions"];
}


#pragma mark -
#pragma mark Misc

- (NSString*)description
{
	return [NSString stringWithFormat:@"host %p id=%@ state=%lu address=%@ rect=%@", self, [self identifier], _state, [self address], NSStringFromRect([self hostRect])];
}


@end

@implementation NSArray (TPRemoteHostAdditions)

- (NSArray*)hostsWithState:(TPHostState)state
{
	NSMutableArray * hosts = [[NSMutableArray alloc] init];
	NSEnumerator * hostEnum = [self objectEnumerator];
	TPRemoteHost * host;
	
	while((host = [hostEnum nextObject]) != nil) {
		if(![host isKindOfClass:[TPRemoteHost class]])
			continue;
		if(([host hostState] & state) != 0)
			[hosts addObject:host];
	}
	
	return hosts;
}

@end
