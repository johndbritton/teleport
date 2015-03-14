//
//  TPHost.m
//  Teleport
//
//  Created by JuL on Sun Dec 07 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import "TPHost.h"
#import "TPPreferencesManager.h"

#define MAX_BACKGROUND_IMAGE_WIDTH 240

NSString * TPHostDidUpdateNotification = @"TPHostDidUpdateNotification";

NSString * TPHostIdentifierKey = @"identifier";
NSString * TPHostComputerNameKey = @"computerName";
NSString * TPHostBackgroundImageDataKey = @"backgroundImage";
NSString * TPHostMacAddressKey = @"macAddress";
NSString * TPHostCapabilitiesKey = @"capabilities";
NSString * TPHostOSVersionKey = @"osVersion";

@implementation TPHost

- (instancetype) init
{
	self = [super init];

	_computerName = nil;
	[self invalidateMACAddress];
	
	return self;
}

- (BOOL)isEqual:(id)object
{
	if(![object isKindOfClass:[TPHost class]])
		return NO;
	
	TPHost * otherObject = (TPHost*)object;

	return [[self identifier] isEqualToString:[otherObject identifier]];
}

#if LEGACY_BUILD
- (unsigned)hash
#else
- (NSUInteger)hash
#endif
{
	return [[self identifier] hash];
}

- (instancetype) initWithCoder:(NSCoder *)coder
{
	self = [super init];
	
	_computerName = [[coder decodeObjectForKey:TPHostComputerNameKey] copy];
	
	if([coder containsValueForKey:TPHostMacAddressKey]) {
		const uint8_t * tempBuffer = [coder decodeBytesForKey:TPHostMacAddressKey returnedLength:NULL];
		memcpy(_macAddress.bytes, tempBuffer, kIOEthernetAddressSize);
	}
	else
		[self invalidateMACAddress];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:[self identifier] forKey:TPHostIdentifierKey];
	[coder encodeObject:[self computerName] forKey:TPHostComputerNameKey];
	IOEthernetAddress address = [self MACAddress];
	[coder encodeBytes:address.bytes length:kIOEthernetAddressSize forKey:TPHostMacAddressKey];
	[coder encodeInt:[self capabilities] forKey:TPHostCapabilitiesKey];
	[coder encodeInt32:[self osVersion] forKey:TPHostOSVersionKey];
	
#if 0 // sent with TPBackgroundImageTransfer
	if([self hasCustomBackgroundImage]) {
		NSData * backgroundImageData = [self backgroundImageData];
		if(backgroundImageData != nil)
			[coder encodeBytes:[backgroundImageData bytes] length:[backgroundImageData length] forKey:TPHostBackgroundImageDataKey];
	}
#endif
}

- (NSString*)identifier
{
	return nil;
}

- (SInt32)osVersion
{
	return 0;
}

- (NSString*)address
{
	return nil;
}

- (NSString*)computerName
{
	if(_computerName == nil)
		return NSLocalizedString(@"unnamed", @"Name for unamed server");
	
	return _computerName;
}

- (void)setComputerName:(NSString*)computerName
{
	if(computerName != _computerName) {
		_computerName = [computerName copy];
		[self notifyChange];
	}
}

- (BOOL)hasValidMACAddress
{
	int i;
	for(i=0; i<kIOEthernetAddressSize; i++) {
		if(_macAddress.bytes[i] != 0)
			return YES;
	}
	
	return NO;
}

- (void)invalidateMACAddress
{
	memset(_macAddress.bytes, 0, kIOEthernetAddressSize);
	[self notifyChange];
}

- (IOEthernetAddress)MACAddress
{
	return _macAddress;
}

- (void)setMACAddress:(IOEthernetAddress)macAddress
{
	_macAddress = macAddress;
}


#pragma mark -
#pragma mark Screen

- (NSArray*)screens
{
	return nil;
}

- (NSScreen*)screenAtIndex:(unsigned)screenIndex
{
	NSArray * screens = [self screens];
	if(screenIndex < [screens count])
		return screens[screenIndex];
	return nil;
}


#pragma mark -
#pragma mark Background image

+ (NSImage*)backgroundImageFromDesktopPicture:(NSImage*)desktopPicture
{
	NSSize size = [desktopPicture size];
	if(size.width <= MAX_BACKGROUND_IMAGE_WIDTH)
		return desktopPicture;
	
	NSRect backgroundImageRect = NSZeroRect;
	backgroundImageRect.size = size;
	
	backgroundImageRect.size.height *= (float)MAX_BACKGROUND_IMAGE_WIDTH/NSWidth(backgroundImageRect);
	backgroundImageRect.size.width = MAX_BACKGROUND_IMAGE_WIDTH;
	
	NSImage * backgroundImage = [[NSImage alloc] initWithSize:backgroundImageRect.size];
	[backgroundImage lockFocus];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[desktopPicture drawInRect:backgroundImageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[backgroundImage unlockFocus];
	
	return backgroundImage;
}

- (NSImage*)defaultBackgroundImage
{
	int osVersion = [self osVersion];
	NSString * imageName = nil;
	NSImage * image = nil;
	
	if(osVersion < TPHostOSVersion(3)) {
		imageName = @"10.2-Jaguar";
	}
	else if(osVersion < TPHostOSVersion(4)) {
		imageName = @"10.3-Panther";
	}
	else if(osVersion < TPHostOSVersion(5)) {
		imageName = @"10.4-Tiger";
	}
	else if(osVersion < TPHostOSVersion(6)) {
		imageName = @"10.5-Leopard";
	}
	else if(osVersion < TPHostOSVersion(7)) {
		imageName = @"10.6-SnowLeopard";
	}
	else if(osVersion < TPHostOSVersion(8)) {
		imageName = @"10.7-Lion";
	}
	else {
		NSImage * fullImage = [[NSImage alloc] initWithContentsOfFile:@"/System/Library/CoreServices/DefaultDesktop.jpg"];
		image = [TPHost backgroundImageFromDesktopPicture:fullImage];
	}
	
	if(image == nil) {
		image = [NSImage imageNamed:imageName];
	}
	
	return image;
}

- (NSImage*)backgroundImage
{
	return nil;
}

- (NSData*)backgroundImageData
{
	NSImage * backgroundImage = [self backgroundImage];
	
	if(backgroundImage != nil) {
#if 0
		NSBitmapImageRep * imageRep = [[backgroundImage representations] objectAtIndex:0];
		NSData * backgroundImageData = [imageRep representationUsingType:NSJPEGFileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor]];
#else
		NSData * backgroundImageData = [backgroundImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
#endif
		return backgroundImageData;
	}
	else
		return nil;
}

- (BOOL)hasCustomBackgroundImage
{
	return NO;
}


#pragma mark -
#pragma mark Capabilities

- (TPHostCapability)capabilities
{
	return TPHostNoCapability;
}

- (BOOL)hasCapability:(TPHostCapability)capability
{
	return NO;
}

- (BOOL)pairWithHost:(TPHost*)host hasCapability:(TPHostCapability)capability
{
	return [host hasCapability:capability] && [self hasCapability:capability];
}

+ (TPHost*)hostFromHostData:(NSData*)hostData
{
	NSKeyedUnarchiver * unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:hostData];
	TPHost * host = [[self alloc] initWithCoder:unarchiver];
	[unarchiver finishDecoding];
	return host;
}

- (NSData*)hostData
{
	NSMutableData * hostData = [[NSMutableData alloc] init];
	NSKeyedArchiver * archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:hostData];
	[self encodeWithCoder:archiver];
	[archiver finishEncoding];
	return hostData;
}

- (void)notifyChange
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(notifyChangeNow) object:nil];
	[self performSelector:@selector(notifyChangeNow) withObject:nil afterDelay:0.1];
}

- (void)notifyChangeNow
{
	[[NSNotificationCenter defaultCenter] postNotificationName:TPHostDidUpdateNotification object:self];
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"identifier=%@ computerName=%@ address=%@", [self identifier], [self computerName], [self address]];
}

@end
