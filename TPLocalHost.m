//
//  TPLocalHost.m
//  teleport
//
//  Created by JuL on Fri Feb 27 2004.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPLocalHost.h"

#import "TPPreferencesManager.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/network/IOEthernetInterface.h>
#include <IOKit/network/IONetworkInterface.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <errno.h>
#include <sys/sysctl.h>

#define FAKE_MULTI_SCREEN 0

NSString * TPLocalHostCapabilitiesChangedNotification = @"TPLocalHostCapabilitiesChangedNotification";

static kern_return_t FindEthernetInterfaces(io_iterator_t *matchingServices)
{
	kern_return_t	 kernResult; 
	CFMutableDictionaryRef	matchingDict;
	CFMutableDictionaryRef	propertyMatchDict;
	
	matchingDict = IOServiceMatching(kIOEthernetInterfaceClass);
	
	if (NULL == matchingDict) {
		printf("IOServiceMatching returned a NULL dictionary.\n");
	}
	else {
		propertyMatchDict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
													  &kCFTypeDictionaryKeyCallBacks,
													  &kCFTypeDictionaryValueCallBacks);
		
		if (NULL == propertyMatchDict) {
			printf("CFDictionaryCreateMutable returned a NULL dictionary.\n");
		}
		else {
			CFDictionarySetValue(propertyMatchDict, CFSTR(kIOPrimaryInterface), kCFBooleanTrue); 
			
			CFDictionarySetValue(matchingDict, CFSTR(kIOPropertyMatchKey), propertyMatchDict);
			CFRelease(propertyMatchDict);
		}
	}
	
	kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, matchingServices);	
	if (KERN_SUCCESS != kernResult) {
		printf("IOServiceGetMatchingServices returned 0x%08x\n", kernResult);
	}
	
	return kernResult;
}

static kern_return_t GetMACAddress(io_iterator_t intfIterator, UInt8 *MACAddress, UInt8 bufferSize)
{
	io_object_t	   intfService;
	io_object_t	   controllerService;
	kern_return_t  kernResult = KERN_FAILURE;
	
	if (bufferSize < kIOEthernetAddressSize) {
		return kernResult;
	}
	
	bzero(MACAddress, bufferSize);
	
	while ((intfService = IOIteratorNext(intfIterator)) != 0)
	{
		CFTypeRef  MACAddressAsCFData;
		kernResult = IORegistryEntryGetParentEntry(intfService,
												   kIOServicePlane,
												   &controllerService);
		
		if (KERN_SUCCESS != kernResult) {
			printf("IORegistryEntryGetParentEntry returned 0x%08x\n", kernResult);
		}
		else {
			MACAddressAsCFData = IORegistryEntryCreateCFProperty(controllerService,
																 CFSTR(kIOMACAddress),
																 kCFAllocatorDefault,
																 0);
			if (MACAddressAsCFData) {
				CFDataGetBytes(MACAddressAsCFData, CFRangeMake(0, kIOEthernetAddressSize), MACAddress);
				CFRelease(MACAddressAsCFData);
			}
			
			(void) IOObjectRelease(controllerService);
		}
		
		(void) IOObjectRelease(intfService);
	}
	
	return kernResult;
}

static TPLocalHost * _localHost = nil;

@interface TPLocalHost (Internal)

- (void)_generateBackgroundImages;
- (NSString*)_desktopPicturePathForScreen:(NSScreen*)screen;
- (NSImage*)_desktopPictureForScreen:(NSScreen*)screen;

@end

@implementation TPLocalHost

+ (TPLocalHost*)localHost
{
	if(_localHost == nil)
		_localHost = [[TPLocalHost alloc] init];
	return _localHost; 
}

- (instancetype) init
{
	self = [super init];
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_generateBackgroundImages) name:@"com.apple.desktop" object:@"BackgroundChanged"];
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessibilityAPIChanged:) name:@"com.apple.accessibility.api" object:nil];

	return self;
}


- (NSString*)identifier
{
	return [[NSWorkspace sharedWorkspace] computerIdentifier];
}

- (SInt32)osVersion
{
	SInt32 MacVersion = 0;
	size_t size = 256;
	char str[size];
	int ret = sysctlbyname("kern.osrelease", str, &size, NULL, 0);

	if (ret == noErr) {
		MacVersion = atoi(str);
	}
	return MacVersion;
}

- (NSString*)address
{
	return @"127.0.0.1";
}

- (NSString*)computerName
{
	if(_computerName == nil)
		_computerName = (NSString *)CFBridgingRelease(CSCopyMachineName());
	
	return [super computerName];
}

- (IOEthernetAddress)MACAddress
{
	if(![self hasValidMACAddress]) {
		kern_return_t  kernResult = KERN_SUCCESS;
		io_iterator_t  intfIterator;
		kernResult = FindEthernetInterfaces(&intfIterator);
		
		if(KERN_SUCCESS != kernResult) {
			printf("FindEthernetInterfaces returned 0x%08x\n", kernResult);
		}
		else {
			kernResult = GetMACAddress(intfIterator, _macAddress.bytes, kIOEthernetAddressSize);
			
			if(KERN_SUCCESS != kernResult) {
				printf("GetMACAddress returned 0x%08x\n", kernResult);
			}
		}
		
		(void)IOObjectRelease(intfIterator);  // Release the iterator.
	}
	
	return [super MACAddress];
}

- (NSArray*)screens
{
#if FAKE_MULTI_SCREEN
	NSMutableArray * screens = [[NSScreen screens] mutableCopy];
	TPScreen * otherScreen = [[TPScreen alloc] init];
	NSRect frame = [[screens objectAtIndex:0] frame];
	frame.origin.x += NSWidth(frame);
	frame.size.width *= 1.5;
	frame.size.height *= 1.5;
	otherScreen.frame = frame;
	[screens addObject:otherScreen];
	[otherScreen release];
	return [screens autorelease];
#else
	return [NSScreen screens];
#endif
}


#pragma mark -
#pragma mark Background image

- (void)_generateBackgroundImages
{
	NSArray * screens = [[TPLocalHost localHost] screens];
	
	
	_backgroundImages = [[NSMutableArray alloc] initWithCapacity:[screens count]];
	
	NSEnumerator * screenEnum = [screens objectEnumerator];
	NSScreen * screen;
	
	while((screen = [screenEnum nextObject]) != nil) {
		NSImage * backgroundImage = nil;
		NSImage * desktopPicture = [self _desktopPictureForScreen:screen];
		if(desktopPicture != nil) {
			backgroundImage = [TPHost backgroundImageFromDesktopPicture:desktopPicture];
		}
		else {
			backgroundImage = [self defaultBackgroundImage];
		}
		if(backgroundImage != nil)
			[_backgroundImages addObject:backgroundImage];
	}
	
	[self notifyChange];
}

- (NSImage*)backgroundImageForScreen:(NSScreen*)screen
{
	if(_backgroundImages == nil)
		[self _generateBackgroundImages];
	
	int index = [[[TPLocalHost localHost] screens] indexOfObject:screen];
	if(index >= 0 && index < [_backgroundImages count])
		return _backgroundImages[index];
	else
		return nil;
}

- (NSImage*)backgroundImage
{
	return [self backgroundImageForScreen:[self mainScreen]];
}

- (BOOL)hasCustomBackgroundImage
{
	return ([self _desktopPicturePathForScreen:[self mainScreen]] != nil);
}

- (NSString*)_desktopPicturePathForScreen:(NSScreen*)screen
{
	if([[NSWorkspace sharedWorkspace] respondsToSelector:@selector(desktopImageURLForScreen:)]) {
		NSURL * desktopPictureURL = [[NSWorkspace sharedWorkspace] desktopImageURLForScreen:screen];
		
		// Addresses issue https://github.com/abyssoft/teleport/issues/15
		if(![[NSFileManager defaultManager] fileExistsAtPath:[desktopPictureURL absoluteString]]){
			return nil;
		} else
			return [desktopPictureURL path];
	}
	else {
		NSUserDefaults * userDefaults = [[NSUserDefaults alloc] init];
		[userDefaults addSuiteNamed:@"com.apple.desktop"];
		[userDefaults synchronize];
		
		NSDictionary * prefDict = [userDefaults dictionaryRepresentation];
		
		NSNumber * screenNum = [screen deviceDescription][@"NSScreenNumber"];
		NSDictionary * backgroundDict = prefDict[@"Background"];
		
		NSDictionary * screenDict = backgroundDict[[screenNum stringValue]];
		if(screenDict == nil)
			screenDict = backgroundDict[@"default"];
		
		NSString * imagePath = nil;
		NSString * change = screenDict[@"Change"];
		if(change != nil && ![change isEqualToString:@"Never"]) {
			imagePath = screenDict[@"ChangePath"];
			imagePath = [imagePath stringByAppendingPathComponent:screenDict[@"LastName"]];
		}
		
		if(imagePath == nil)
			imagePath = screenDict[@"ImageFilePath"];
		
		
		if(imagePath == nil)
			return nil;
		
		if(![[NSFileManager defaultManager] fileExistsAtPath:imagePath])
			return nil;
		
		return imagePath;
	}
}

- (NSImage*)_desktopPictureForScreen:(NSScreen*)screen
{
	NSString * path = [self _desktopPicturePathForScreen:screen];
	if(path == nil)
		return nil;
	
	NSImage * desktopPicture = [[NSImage alloc] initByReferencingFile:path];
	return desktopPicture;
}


#pragma mark -
#pragma mark Capabilities

- (TPHostCapability)capabilities
{
	TPHostCapability capabilities = TPHostNoCapability;
	
	int c;
	for(c=0; c<=MAX_CAPABILITIES; c++) {
		TPHostCapability capability = (1 << c);
		
		if([self hasCapability:capability])
			capabilities |= capability;
	}
	
	return capabilities;
}

- (BOOL)isAccessibilityAPIEnabled
{
	return AXAPIEnabled();
}

- (BOOL)checkAccessibility
{
	return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString*)kAXTrustedCheckOptionPrompt: @YES});
}

- (BOOL)hasCapability:(TPHostCapability)capability
{
	switch(capability) {
		case TPHostEncryptionCapability:
			return [self hasIdentity] && [[TPPreferencesManager sharedPreferencesManager] boolForPref:ENABLED_ENCRYPTION];
		case TPHostEventTapsCapability:
			return ([self osVersion] >= TPHostOSVersion(4)) && [self isAccessibilityAPIEnabled];
		case TPHostDirectEventTapsCapability:
			return ([self osVersion] >= TPHostOSVersion(5)) && [self isAccessibilityAPIEnabled] && ![[TPPreferencesManager sharedPreferencesManager] boolForPref:TIGER_BEHAVIOR];
		default:
			return NO;
	}
	
	return NO;
}

- (void)checkCapabilities
{
	[self willChangeValueForKey:@"supportDragNDrop"];
	[self didChangeValueForKey:@"supportDragNDrop"];
}

- (void)_accessibilityAPIChanged:(NSNotification*)notification
{
	[self notifyChange];
}


#pragma mark -
#pragma mark Identity

- (SecKeychainRef)_keychainRef
{
	static SecKeychainRef keychainRef = NULL;
	
	if(keychainRef == NULL) {
		OSErr err;
		NSString * keychainName = nil;
		
		if(keychainName != nil) {
			NSString * keychainsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Keychains"];
			NSString * fullPath = [keychainsDirectory stringByAppendingPathComponent:keychainName];
			
			if((err = SecKeychainOpen([fullPath UTF8String], &keychainRef)) != noErr) {
				NSLog(@"Unable to open keychain: %d", err);
			}
		}
		else if((err = SecKeychainCopyDefault(&keychainRef)) != noErr) {
			NSLog(@"Unable to copy default keychain: %d", err);
		}
	}
		
	return keychainRef;
}

- (id)_identifierForIdentity:(SecIdentityRef)identity
{
	UInt32 tags[] = { kSecPublicKeyHashItemAttr };
	UInt32 formats[] = { CSSM_DB_ATTRIBUTE_FORMAT_BLOB };
	SecKeychainAttributeInfo info = { 1, tags, formats };
	SecKeychainAttributeList * attrList = NULL;
	
	OSStatus err;
	
	SecCertificateRef certRef;
	if((err = SecIdentityCopyCertificate(identity, &certRef)) != noErr) {
		NSLog(@"Unable to copy certificate: %d", err);
		return nil;
	}
	
	if((err = SecKeychainItemCopyAttributesAndData((SecKeychainItemRef)certRef, &info, NULL, &attrList, NULL, NULL)) != noErr) {
		NSLog(@"Unable to copy identifier: %d", err);
		CFRelease(certRef);
		return nil;
	}
	
	CFRelease(certRef);
	
	if(attrList->count != 1) {
		NSLog(@"unexpected number of serial number: %d", attrList->count);
		SecKeychainItemFreeAttributesAndData(attrList, NULL);
		return nil;
	}
	
	SecKeychainAttribute identifierAttribute = attrList->attr[0];
	
	NSData * identifierData = [[NSData alloc] initWithBytes:identifierAttribute.data length:identifierAttribute.length];
	SecKeychainItemFreeAttributesAndData(attrList, NULL);
	return identifierData;
}

- (NSArray*)potentialIdentities
{
	if(_potentialIdentities == nil) {
		OSErr err;
		
		SecKeychainRef keychainRef = [self _keychainRef];
		
		SecIdentitySearchRef searchRef = NULL;
		if((err = SecIdentitySearchCreate(keychainRef, CSSM_KEYUSE_ENCRYPT|CSSM_KEYUSE_DECRYPT|CSSM_KEYUSE_SIGN|CSSM_KEYUSE_VERIFY, &searchRef)) != noErr) {
			NSLog(@"Unable to create keychain search: %d", err);
			CFRelease(keychainRef);
			return nil;
		}
		
		id identifier = [[TPPreferencesManager sharedPreferencesManager] valueForPref:CERTIFICATE_IDENTIFIER];
		NSMutableArray * potentialIdentities = [[NSMutableArray alloc] init];
		SecIdentityRef identityRef;
		
		while((err = SecIdentitySearchCopyNext(searchRef, &identityRef)) == noErr) {
			id identityIdentifier = [self _identifierForIdentity:identityRef];
			if((identifier != nil) && [identifier isEqual:identityIdentifier]) {
				[potentialIdentities insertObject:(id)CFBridgingRelease(identityRef) atIndex:0]; // put current identity first in the potential identities
			}
			else {
				[potentialIdentities addObject:(id)CFBridgingRelease(identityRef)];
			}
		}
		
		CFRelease(searchRef);
		
		if(err != errSecItemNotFound) {
			DebugLog(@"Unable to get next search result: %d", err);
		}
		else {
			_potentialIdentities = potentialIdentities;
		}
	}
	
	return _potentialIdentities;
}

- (SecIdentityRef)identity
{
	NSArray * potentialIdentities = [self potentialIdentities];
	
	if(potentialIdentities == nil || ([potentialIdentities count] == 0)) {
		return NULL;
	}
	else {
		return (__bridge SecIdentityRef)potentialIdentities[0];
	}
}
					
- (void)setIdentity:(SecIdentityRef)identity
{
	if(identity != NULL) {
		id identifier = [self _identifierForIdentity:identity];
		[[TPPreferencesManager sharedPreferencesManager] setValue:identifier forKey:CERTIFICATE_IDENTIFIER];
	}
	
	[self reloadIdentity];
}

- (BOOL)hasIdentity
{
	return ([self identity] != NULL);
}

- (void)resetIdentity
{
	[self setIdentity:NULL];
}

- (void)reloadIdentity
{
	_potentialIdentities = nil;
}

- (NSString*)bonjourName
{
	return [NSString stringWithFormat:@"%@@%@", NSUserName(), [self computerName]];
}


#pragma mark -
#pragma mark Screen

- (NSScreen*)mainScreen
{
	return [self screenAtIndex:0];
}

- (NSScreen*)sharedScreen
{
	NSScreen * sharedScreen = [self screenAtIndex:[self sharedScreenIndex]];
	
	if(sharedScreen == nil) {
		sharedScreen = [self mainScreen];
	}
	
	return sharedScreen;
}

- (void)setSharedScreenIndex:(unsigned)screenIndex
{
	[[TPPreferencesManager sharedPreferencesManager] setValue:@(screenIndex) forKey:SHARED_SCREEN_INDEX];
	[self notifyChange];
}

- (unsigned)sharedScreenIndex
{
	return [[[TPPreferencesManager sharedPreferencesManager] valueForKey:SHARED_SCREEN_INDEX] unsignedIntValue];
}

- (void)wakeUpScreen
{
	IOPMAssertionID assertionID;
	IOReturn success = IOPMAssertionCreate(kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn, &assertionID);
	if(success == kIOReturnSuccess) {
		IOPMAssertionRelease(assertionID);
	}
	
	io_registry_entry_t entry = IORegistryEntryFromPath(kIOMasterPortDefault,
														"IOService:/IOResources/IODisplayWrangler");
	if (entry != MACH_PORT_NULL) {
		IORegistryEntrySetCFProperty(entry, CFSTR("IORequestIdle"), kCFBooleanFalse);
		IOObjectRelease(entry);
	}

	// The previous code doesn't appear to work on Big Sur, but explicitly declaring user activity does. This should be cleaned up.
	success = IOPMAssertionDeclareUserActivity(CFSTR("teleport waking screen"), kIOPMUserActiveLocal, &assertionID);
	if(success == kIOReturnSuccess) {
		IOPMAssertionRelease(assertionID);
	}
}

- (void)sleepScreen {
	/* This doesn't work on Big Sur */
	io_registry_entry_t entry = IORegistryEntryFromPath(kIOMasterPortDefault,
														"IOService:/IOResources/IODisplayWrangler");
	if (entry != MACH_PORT_NULL) {
		IORegistryEntrySetCFProperty(entry, CFSTR("IORequestIdle"), kCFBooleanTrue);
		IOObjectRelease(entry);
	}
}


- (id)valueForUndefinedKey:(NSString*)key
{
	if([key isEqualToString:@"supportDragNDrop"])
		return @([self hasCapability:TPHostDragNDropCapability]);
	else
		return [super valueForUndefinedKey:key];
}

@end
