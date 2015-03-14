//
//  TPUtils.m
//  teleport
//
//  Created by Julien Robert on 11/10/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import "TPUtils.h"

#include <Carbon/Carbon.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/network/IOEthernetInterface.h>
#include <IOKit/network/IONetworkInterface.h>
#include <IOKit/network/IOEthernetController.h>

#import <SecurityFoundation/SFAuthorization.h>

@interface NSObject (AdminPrivate)

+ (BOOL)createFileWithContents:(NSData *)inData path:(NSString *)inPath attributes:(NSDictionary *)inAttributes;
+ (BOOL)removeFileAtPath:(NSString *)inPath;

+ (id)sharedAuthenticator;
- (BOOL)authenticateUsingAuthorizationSync:(SFAuthorization*)auth;

@end

@implementation NSData (TPUtils)

- (void)_readBytes:(void*)bytes withSize:(unsigned int)size atPos:(int*)pos
{
	[self getBytes:bytes range:NSMakeRange(*pos, size)];
	*pos += size;
}

+ (NSData*)dataWithRect:(NSRect)rect
{
	NSMutableData * data = [[NSMutableData alloc] init];
	
	[data appendData:[self dataWithPoint:rect.origin]];
	[data appendData:[self dataWithSize:rect.size]];
	
	return data;
}

- (NSRect)rectValue
{
	int pos = 0;
	
	NSSwappedFloat originX;
	NSSwappedFloat originY;
	NSSwappedFloat sizeWidth;
	NSSwappedFloat sizeHeight;
	
	[self _readBytes:&originX withSize:sizeof(NSSwappedFloat) atPos:&pos];
	[self _readBytes:&originY withSize:sizeof(NSSwappedFloat) atPos:&pos];
	[self _readBytes:&sizeWidth withSize:sizeof(NSSwappedFloat) atPos:&pos];
	[self _readBytes:&sizeHeight withSize:sizeof(NSSwappedFloat) atPos:&pos];
	
	return NSMakeRect(NSSwapBigFloatToHost(originX), NSSwapBigFloatToHost(originY), NSSwapBigFloatToHost(sizeWidth), NSSwapBigFloatToHost(sizeHeight));
}

+ (NSData*)dataWithPoint:(NSPoint)point
{
	NSMutableData * data = [[NSMutableData alloc] init];
	
	NSSwappedFloat x = NSSwapHostFloatToBig(point.x);
	NSSwappedFloat y = NSSwapHostFloatToBig(point.y);
	
	[data appendData:[NSData dataWithBytes:&x length:sizeof(NSSwappedFloat)]];
	[data appendData:[NSData dataWithBytes:&y length:sizeof(NSSwappedFloat)]];
	
	return data;
}

- (NSPoint)pointValue
{
	int pos = 0;
	
	NSSwappedFloat x;
	NSSwappedFloat y;
	
	[self _readBytes:&x withSize:sizeof(NSSwappedFloat) atPos:&pos];
	[self _readBytes:&y withSize:sizeof(NSSwappedFloat) atPos:&pos];
	
	return NSMakePoint(NSSwapBigFloatToHost(x), NSSwapBigFloatToHost(y));
}

+ (NSData*)dataWithSize:(NSSize)size
{
	NSMutableData * data = [[NSMutableData alloc] init];
	
	NSSwappedFloat width = NSSwapHostFloatToBig(size.width);
	NSSwappedFloat height = NSSwapHostFloatToBig(size.height);
	
	[data appendData:[NSData dataWithBytes:&width length:sizeof(NSSwappedFloat)]];
	[data appendData:[NSData dataWithBytes:&height length:sizeof(NSSwappedFloat)]];
	
	return data;
}

- (NSSize)sizeValue
{
	int pos = 0;
	
	NSSwappedFloat width;
	NSSwappedFloat height;
	
	[self _readBytes:&width withSize:sizeof(NSSwappedFloat) atPos:&pos];
	[self _readBytes:&height withSize:sizeof(NSSwappedFloat) atPos:&pos];
	
	return NSMakeSize(NSSwapBigFloatToHost(width), NSSwapBigFloatToHost(height));
}

+ (NSData*)dataWithString:(NSString*)string
{
	return [string dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString*)stringValue
{
	NSString * string = [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
	return string;
}

+ (NSData*)dataWithInt:(int)i
{
	return [self dataWithString:[NSString stringWithInt:i]];
}

- (int)intValue
{
	return [[self stringValue] intValue];
}

+ (NSData*)dataWithBool:(BOOL)b
{
	return [self dataWithString:[NSString stringWithBool:b]];
}

- (BOOL)boolValue
{
	return [[self stringValue] boolValue];
}

@end

@implementation NSString (TPAdditions)

#define KILO (1024)
#define MEGA (KILO*KILO)
#define GIGA (KILO*MEGA)

+ (NSString*)sizeStringForSize:(TPDataLength)size
{
	if(size == 0)
		return NSLocalizedString(@"zero", nil);
	
	double s;
	NSString * sizeString;
	
	if(size >= GIGA) {
		s = (10*(double)size)/GIGA;
		sizeString = [NSString stringWithFormat:NSLocalizedString(@"%.1fG", nil), s/10];
	}
	else if(size >= MEGA) {
		s = (10*(double)size)/MEGA;
		sizeString = [NSString stringWithFormat:NSLocalizedString(@"%.1fM", nil), s/10];
	}
	else if(size >= KILO) {
		s = (10*(double)size)/KILO;
		sizeString = [NSString stringWithFormat:NSLocalizedString(@"%.1fK", nil), s/10];
	}
	else
		sizeString = NSLocalizedString(@"< 1K", nil);

	return sizeString;
}

+ (NSString*)stringWithInt:(int)i
{
	return [NSString stringWithFormat:@"%d", i];
}

+ (NSString*)stringWithBool:(BOOL)b
{
	return b?@"true":@"false";
}

- (NSString*)stringValue
{
	return self;
}

- (BOOL)boolValue
{
	return [[self lowercaseString] isEqualToString:@"true"];
}

@end

@implementation NSWorkspace (TPAdditions)

- (NSDictionary*)typeDictForPath:(NSString*)path
{
	char fspath[PATH_MAX];
	FSRef fsRef;
	LSItemInfoRecord itemInfo;
	Boolean isDirectory;
	
	if(path == nil)
		return nil;

	if(!CFStringGetFileSystemRepresentation((CFStringRef)path, fspath, PATH_MAX))
		return nil;
	
	FSPathMakeRef((const UInt8 *)fspath, &fsRef, &isDirectory);
	LSCopyItemInfoForRef(&fsRef, kLSRequestAllInfo, &itemInfo);
	
	if(isDirectory) {
		if(itemInfo.flags & kLSItemInfoIsApplication)
			itemInfo.filetype = kGenericApplicationIcon;
		else if(itemInfo.flags & kLSItemInfoIsPackage)
			itemInfo.filetype = kGenericComponentIcon;
		else if(itemInfo.flags & kLSItemInfoIsVolume)
			itemInfo.filetype = kGenericRemovableMediaIcon;
		else
			itemInfo.filetype = kGenericFolderIcon;
	}
	
	NSMutableDictionary * typeDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedLong:itemInfo.filetype], NSFileHFSTypeCode,
		[NSNumber numberWithUnsignedLong:itemInfo.creator], NSFileHFSCreatorCode,
		nil];
	
	if(itemInfo.extension != NULL) {
		typeDict[NSFileType] = (__bridge NSString*)itemInfo.extension;
		CFRelease(itemInfo.extension);
	}
	
	return typeDict;
}

#define MAX_NUMBER 5
- (NSString*)computerIdentifier
{
	NSString * computerIdentifier = nil;
	kern_return_t kernResult = KERN_FAILURE;

	NSString * const interfaceNameFormat = @"en%d";
	int interfaceNumber = 0;
	
	while((computerIdentifier == nil) && (interfaceNumber < MAX_NUMBER)) {
		NSString * interfaceName = [NSString stringWithFormat:interfaceNameFormat, interfaceNumber];
		const char * interfaceNameString = NULL;
		
#if LEGACY_BUILD
		interfaceNameString = [interfaceName cString];
#else
		interfaceNameString = [interfaceName cStringUsingEncoding:NSASCIIStringEncoding];
#endif
		
		CFMutableDictionaryRef matchingDict = IOBSDNameMatching(kIOMasterPortDefault, 0, interfaceNameString);
		if(matchingDict == NULL) {
			continue;
		}
		
		io_iterator_t iterator;
		io_object_t service;
		
		kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator);
		
		if(kernResult != KERN_SUCCESS) {
			continue;
		}
		
		while((service = IOIteratorNext(iterator)) != 0) {
			io_object_t controllerService;	

			kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &controllerService);
			
			if(kernResult != KERN_SUCCESS) {
				break;
			}
			else {
				CFTypeRef MACData = IORegistryEntryCreateCFProperty(controllerService, CFSTR(kIOMACAddress), kCFAllocatorDefault, 0);
				if(MACData != NULL) {
					UInt8 MACAddress[kIOEthernetAddressSize];
					CFDataGetBytes(MACData, CFRangeMake(0, kIOEthernetAddressSize), MACAddress);
					CFRelease(MACData);
					
					computerIdentifier = [NSString stringWithFormat:@"%02x-%02x-%02x-%02x-%02x-%02x", MACAddress[0], MACAddress[1], MACAddress[2], MACAddress[3], MACAddress[4], MACAddress[5]];
				}
				
				IOObjectRelease(controllerService);
			}
			
			IOObjectRelease(service);
		}
		
		interfaceNumber++;
	}
	
	return computerIdentifier; 
}

- (void)_executeThreadedScript:(NSAppleScript*)script
{
	@autoreleasepool {
		[script executeAndReturnError:NULL];
	}
}

@end

@implementation NSFileManager (TPAdditions)

- (BOOL)isTotalSizeOfItemAtPath:(NSString*)path smallerThan:(unsigned long long)maxSize
{
	DebugLog(@"checking that size of %@ is smaller than %lld", path, maxSize);
	BOOL directory;
	if([self fileExistsAtPath:path isDirectory:&directory]) {
		if(directory) {
			unsigned long long folderSize = 0;
			NSDirectoryEnumerator * dirEnum = [self enumeratorAtPath:path];
			
			NSString * file;
			while((file = [dirEnum nextObject]) != nil) {
				NSDictionary * attributes = [dirEnum fileAttributes];
				if([[attributes fileType] isEqualToString:NSFileTypeRegular]) {
					folderSize += [attributes fileSize];
					if(folderSize > maxSize)
						return NO;
				}
			}
			
			return YES;
		}
		else {
			NSDictionary * attributes = [self fileAttributesAtPath:path traverseLink:NO];
			return ([attributes fileSize] <= maxSize);
		}
	}
	else
		return NO;
}

@end
