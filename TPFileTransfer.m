//
//  TPFileTransfer.m
//  teleport
//
//  Created by JuL on 14/02/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import "TPTransfer_Private.h"
#import "TPFileTransfer.h"

#import "TPMainController.h"
#import "TPEventsController.h"
#import "TPConnectionController.h"
#import "TPNetworkConnection.h"
#import "TPTCPSecureSocket.h"
#import "TPHotBorder.h"
#import "TPMessage.h"

NSString * TPFileTransferRepresentedFilesKey = @"TPFileTransferRepresentedFiles";
NSString * TPFileTransferDragImageDataKey = @"TPFileTransferDragImageData";
NSString * TPFileTransferDragImageLocationKey = @"TPFileTransferDragImageLocation";

@interface TPIncomingFileTransfer (Internal)

- (NSArray*)_dragEndedAtPath:(NSString*)path;

@end

@implementation TPOutgoingFileTransfer


- (NSString*)type
{
	return @"TPIncomingFileTransfer";
}

- (BOOL)shouldBeEncrypted
{
	return YES;
}

- (BOOL)requireTrustedHost
{
	return YES;
}

- (TPTransferPriority)priority
{
	return TPTransferMediumPriority;
}

- (BOOL)hasFeedback
{
	return YES;
}

- (NSString*)completionMessage
{
	NSString * sizeString = [NSString sizeStringForSize:[self totalDataLength]];
	return [NSString stringWithFormat:NSLocalizedString(@"File sent (%@)", nil), sizeString];
}

- (NSString*)errorMessage
{
	return NSLocalizedString(@"File not sent", nil);
}

- (void)setFilePaths:(NSArray*)filePaths dragImage:(NSImage*)image location:(NSPoint)point
{
	_archiver = [[TPFileArchiver alloc] initForReadingFilesAtPaths:filePaths delegate:self];
	
	if(image != nil) {
		_dragImage = image;
		_dragImageLocation = point;
	}
}

- (NSDictionary*)infoDict
{
	NSMutableDictionary * infoDict = [[NSMutableDictionary alloc] initWithDictionary:[super infoDict]];

	infoDict[TPFileTransferRepresentedFilesKey] = [_archiver representedFiles];
	
	if(_dragImage != nil) {
		NSData * dragImageData = [_dragImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
		infoDict[TPFileTransferDragImageDataKey] = dragImageData;
		infoDict[TPFileTransferDragImageLocationKey] = NSStringFromPoint(_dragImageLocation);
	}
	
	return infoDict;
}

- (void)_beginTransfer
{
	[super _beginTransfer];
	[_manager transfer:self didProgress:-1.0];
	[_archiver startReading];
}

- (void)fileArchiver:(TPFileArchiver*)archiver hasDataAvailable:(NSData*)data
{
	DebugLog(@"sending data: %d", (int)[data length]);
	_totalDataLength += [data length];
	[_socket sendData:data];
}

- (void)tcpSocketDidSendData:(TPTCPSocket*)tcpSocket
{
	DebugLog(@"did send");
	[_archiver continueReading];
}

- (void)fileArchiverDidCompleteReading:(TPFileArchiver*)archiver
{
	DebugLog(@"fileArchiverDidCompleteReading: %@", archiver);
	[self _senderDataTransferCompleted];
}

@end

#pragma mark -

@interface TPIncomingFileTransfer ()

@property (nonatomic, weak) TPHotBorder * hotBorder;

@end

@implementation TPIncomingFileTransfer

- (BOOL)shouldBeEncrypted
{
	return YES;
}

- (BOOL)requireTrustedHost
{
	return YES;
}

- (TPTransferPriority)priority
{
	return TPTransferMediumPriority;
}

- (BOOL)hasFeedback
{
	return YES;
}

- (NSString*)completionMessage
{
	NSString * sizeString = [NSString sizeStringForSize:_totalDataLength];
	return [NSString stringWithFormat:NSLocalizedString(@"File received (%@)", nil), sizeString];
}

- (NSString*)errorMessage
{
	return NSLocalizedString(@"File not received", nil);
}

- (NSString*)_temporaryDestinationPath
{
	return [[NSTemporaryDirectory() stringByAppendingPathComponent:@"teleport-transfers"] stringByAppendingPathComponent:[self uid]];
}

#define THREADED_DRAG 0
- (BOOL)prepareToReceiveDataWithInfoDict:(NSDictionary*)infoDict fromHost:(TPRemoteHost*)host onPort:(int*)port delegate:(id)delegate
{
	_representedFiles = infoDict[TPFileTransferRepresentedFilesKey];
	
	NSData * dragImageData = infoDict[TPFileTransferDragImageDataKey];
	if(dragImageData != nil) {
		_dragImage = [[NSImage alloc] initWithData:dragImageData];
		_dragImageLocation = NSPointFromString(infoDict[TPFileTransferDragImageLocationKey]);
	}
	
	NSString * temporaryDestinationPath = [self _temporaryDestinationPath];
	
	if(![[NSFileManager defaultManager] fileExistsAtPath:temporaryDestinationPath isDirectory:NULL]) {
		if(![[NSFileManager defaultManager] createDirectoryAtPath:temporaryDestinationPath withIntermediateDirectories:YES attributes:nil error:NULL]) {
			return NO;
		}
	}
	
	_unarchiver = [[TPFileUnarchiver alloc] initForWritingAtPath:temporaryDestinationPath];
	[_unarchiver startWriting];
	
	if([delegate respondsToSelector:@selector(currentHotBorder)]) {
		TPHotBorder * hotBorder = [delegate currentHotBorder];
		if(hotBorder == nil) {
			DebugLog(@"currentHotBorder is nil!");
			return NO;
		}
		
		if([delegate respondsToSelector:@selector(eventsController)]) {
			TPEventsController * eventsController = [delegate eventsController];
			if(eventsController == nil) {
				DebugLog(@"eventsController is nil!");
				return NO;
			}
			
			[hotBorder setOpaqueToMouseEvents:YES];
			
			self.hotBorder = hotBorder;
			
			NSPoint currentPoint = [NSEvent mouseLocation];
			NSPoint centerPoint = [hotBorder convertBaseToScreen:NSMakePoint(NSMidX([[hotBorder contentView] bounds]), NSMidY([[hotBorder contentView] bounds]))];
			DebugLog(@"current=%@ center=%@", NSStringFromPoint(currentPoint), NSStringFromPoint(centerPoint));
			centerPoint.y = NSMaxY([[hotBorder screen] frame]) - centerPoint.y;
			currentPoint.y = NSMaxY([[hotBorder screen] frame]) - currentPoint.y;
			
			[eventsController mouseDownAtPosition:centerPoint];
			[eventsController warpMouseToPosition:currentPoint];
			//			CGPostMouseEvent(*(CGPoint*)&centerPoint, TRUE, 1, YES);
			//			CGPostMouseEvent(*(CGPoint*)&currentPoint, TRUE, 1, YES);
			
			
			DebugLog(@"Start drag of files: %@", _representedFiles);
			
#if THREADED_DRAG
			[NSThread detachNewThreadSelector:@selector(startDragUsingHotBorder:) toTarget:self withObject:hotBorder];
#else
			[self performSelector:@selector(startDragUsingHotBorder:) withObject:hotBorder];
#endif
			
			return [super prepareToReceiveDataWithInfoDict:infoDict fromHost:host onPort:port delegate:delegate];
		}
		else {
			DebugLog(@"delegate does not responds to eventsController!");
			return NO;
		}
	}
	else {
		DebugLog(@"delegate does not responds to currentHotBorder!");
		return NO;
	}
}

- (void)startDragUsingHotBorder:(TPHotBorder*)hotBorder
{
	@autoreleasepool {
		NSPasteboard * pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		
		NSMutableArray * fileTypes = [[NSMutableArray alloc] init];
		NSEnumerator * representedFilesEnum = [_representedFiles objectEnumerator];
		NSDictionary * representedFile;
		while((representedFile = [representedFilesEnum nextObject])) {
			NSString * fileType = representedFile[TPFileArchiverTypeKey];
			[fileTypes addObject:fileType];
		}
		
		NSImage * image;
		NSSize offset = NSZeroSize;
		if(_dragImage == nil) {
			if([_representedFiles count] == 1) {
				NSString * fileType = fileTypes[0];
				image = [[[NSWorkspace sharedWorkspace] iconForFileType:fileType] copy];
				[image setScalesWhenResized:YES];
				[image setSize:NSMakeSize(64, 64)];
			}
			else {
				image = [[NSImage imageNamed:@"MultipleFiles.icns"] copy];
				[image setScalesWhenResized:YES];
				[image setSize:NSMakeSize(64, 64)];
			}		
		}
		else {
			image = _dragImage;
			offset.width = _dragImageLocation.x;
			offset.height = _dragImageLocation.y;
		}
		
		NSPoint point = [hotBorder mouseLocationOutsideOfEventStream];
		NSEvent * fakeEvent = [NSEvent mouseEventWithType:NSLeftMouseDown location:point modifierFlags:0 timestamp:0 windowNumber:[hotBorder windowNumber] context:[NSGraphicsContext currentContext] eventNumber:0 clickCount:1 pressure:0.0];
		
		[[hotBorder contentView] dragPromisedFilesOfTypes:fileTypes fromRect:NSMakeRect(point.x - 16.0, point.y - 16.0, 0.0, 0.0) source:self slideBack:NO event:fakeEvent];
	}
}

#if LEGACY_BUILD
- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
#else
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
#endif
{
	return NSDragOperationCopy;
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
{
	DebugLog(@"Drop at location: %@", dropDestination);
	
	return [self _dragEndedAtPath:[dropDestination path]];
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
	if(operation == NSDragOperationNone) {
		DebugLog(@"Drop aborted");
		[self _dragEndedAtPath:nil];
	}
}

- (NSString*)_filePathFromDestinationPath:(NSString*)destinationPath andFileName:(NSString*)fileName
{
	NSString * filePath = [destinationPath stringByAppendingPathComponent:fileName];
	
	if([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
		NSAlert * alert = [NSAlert alertWithMessageText:NSLocalizedString(@"A file already exists with this name.", @"Title of the dialog that appears when dragging to a file that already exists in the Finder") defaultButton:NSLocalizedString(@"Unique", @"Unique button in dialog, to make a unique name of an existing filename") alternateButton:NSLocalizedString(@"Cancel", @"Generic cancel button in dialog")  otherButton:NSLocalizedString(@"Replace", @"Replace button to replace an existing file.") informativeTextWithFormat:NSLocalizedString(@"A file named \\U201C%@\\U201D already exists in \\U201C%@\\U201D. You can choose to use a unique name for the new file, replace the old file, or cancel the drop.", @"Explanation text for the dialog that appears when dragging a file to a location where a file with the same name already exists."), fileName, [destinationPath lastPathComponent]];
		
		int returnCode = [(TPMainController*)[NSApp delegate] presentAlert:alert];
		switch(returnCode) {
			case NSAlertDefaultReturn:
			{
				NSString * name = [fileName stringByDeletingPathExtension];
				NSString * extension = [fileName pathExtension];
				int count = 1;
				do {
					fileName = [name stringByAppendingFormat:@" %d", count++];
					if([extension length] > 0)
						fileName = [fileName stringByAppendingPathExtension:extension];
					filePath = [destinationPath stringByAppendingPathComponent:fileName];
				} while([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
				break;
			}
			case NSAlertAlternateReturn:
				return nil;
			case NSAlertOtherReturn:
			default:
				if(![[NSFileManager defaultManager] removeFileAtPath:filePath handler:nil]) {
					DebugLog(@"couldn't remove file at %@", filePath);
					NSBeep();
					return nil;
				}
		}
	}
	
	return filePath;
}

- (void)_putItemsInPlace
{
	NSString * tempDestinationPath = [self _temporaryDestinationPath];
	NSEnumerator * representedFilesEnum = [_representedFiles objectEnumerator];
	NSDictionary * representedFile;
	while((representedFile = [representedFilesEnum nextObject])) {
		NSString * filename = representedFile[TPFileArchiverNameKey];
		NSString * destPath = _destinationPaths[filename];
		
		if(destPath == nil) continue;
		
		NSString * tempPath = [tempDestinationPath stringByAppendingPathComponent:filename];
		DebugLog(@"move %@ to %@", tempPath, destPath);
		[[NSFileManager defaultManager] removeItemAtPath:destPath error:NULL]; // remove placeholder
		[[NSFileManager defaultManager] moveItemAtPath:tempPath toPath:destPath error:NULL];
	}
	
	[[NSFileManager defaultManager] removeItemAtPath:tempDestinationPath error:NULL]; // remove temp folder
}

- (BOOL)_completeTransferIfPossible
{
	DebugLog(@"_completeTransferIfPossible");
	if(_destinationPaths != nil && _unarchiver == nil) {
		DebugLog(@"YUP!");
		[NSThread detachNewThreadSelector:@selector(_putItemsInPlace) toTarget:self withObject:nil];
		return YES;
	}
	else {
		return NO;
	}
}

- (NSArray*)_dragEndedAtPath:(NSString*)destinationPath
{
	if(destinationPath == nil) {
		[self _fileDropped];
		[self _receiverDataTransferAborted]; // cancel transfer if drop aborted
		return nil;
	}
	
	DebugLog(@"drag ended at %@", destinationPath);
	_destinationPaths = [[NSMutableDictionary alloc] init];
	
	NSMutableArray * filenames = [NSMutableArray array];
	NSEnumerator * representedFilesEnum = [_representedFiles objectEnumerator];
	NSDictionary * representedFile;
	while((representedFile = [representedFilesEnum nextObject])) {
		NSString * filename = representedFile[TPFileArchiverNameKey];
		NSString * path = [self _filePathFromDestinationPath:destinationPath andFileName:filename];
		
		if(path != nil) {
			_destinationPaths[filename] = path;
			[filenames addObject:[path lastPathComponent]];
		}
		else {
			[_destinationPaths removeObjectForKey:filename];
		}
	}
	
	if([_destinationPaths count] == 0) {
		_destinationPaths = nil;
	}
	
	DebugLog(@"destinationPaths: %@", _destinationPaths);
	
	// If transfer is not complete yet, create placeholder files
	if(![self _completeTransferIfPossible]) {
		NSEnumerator * representedFilesEnum = [_representedFiles objectEnumerator];
		NSDictionary * representedFile;
		while((representedFile = [representedFilesEnum nextObject])) {
			NSString * filename = representedFile[TPFileArchiverNameKey];
			NSString * fileType = representedFile[TPFileArchiverTypeKey];
			NSString * path = _destinationPaths[filename];
			
			if(path == nil) continue;
			
			DebugLog(@"create placeholder at: %@", path);
			
			[[NSFileManager defaultManager] createFileAtPath:path contents:[NSData data] attributes:nil];
			
			NSImage * tempImage = [[NSImage alloc] initWithSize:NSMakeSize(128, 128)];
			NSImage * haloImage = [NSImage imageNamed:@"halo.png"];
			NSImage * fileTypeImage = [[[NSWorkspace sharedWorkspace] iconForFileType:fileType] copy];
			[fileTypeImage setSize:NSMakeSize(128, 128)];
			
			NSSize haloSize = [haloImage size];
			float halfHaloHeight = floorf(haloSize.height / 2.0);
			
			// dim icon
			[fileTypeImage lockFocus];
			[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
			NSRectFillUsingOperation(NSMakeRect(0, 0, 128, 128), NSCompositeSourceAtop);
			[fileTypeImage unlockFocus];
			
			[tempImage lockFocus];
			
			// draw halos
			NSRect haloFromRect = NSMakeRect(0.0, halfHaloHeight, haloSize.width, haloSize.height - halfHaloHeight);
			NSRect haloRect = NSMakeRect(0.0, 0.0, haloSize.width, haloSize.height - halfHaloHeight);
			
			haloRect.origin.y = 32.0;
			[haloImage drawInRect:haloRect fromRect:haloFromRect operation:NSCompositeSourceOver fraction:0.8];
			haloRect.origin.y = 42.0;
			[haloImage drawInRect:haloRect fromRect:haloFromRect operation:NSCompositeSourceOver fraction:0.6];
			haloRect.origin.y = 64.0;
			[haloImage drawInRect:haloRect fromRect:haloFromRect operation:NSCompositeSourceOver fraction:0.4];
			haloRect.origin.y = 96.0;
			[haloImage drawInRect:haloRect fromRect:haloFromRect operation:NSCompositeSourceOver fraction:0.2];
			
			[fileTypeImage drawInRect:NSMakeRect(0, 0, 128, 128) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
			
			haloFromRect.origin.y = 0.0;
			haloFromRect.size.height = halfHaloHeight;
			haloRect.size.height = halfHaloHeight;
			
			haloRect.origin.y = 32.0 - halfHaloHeight;
			[haloImage drawInRect:haloRect fromRect:haloFromRect operation:NSCompositeSourceOver fraction:0.8];
			haloRect.origin.y = 42.0 - halfHaloHeight;
			[haloImage drawInRect:haloRect fromRect:haloFromRect operation:NSCompositeSourceOver fraction:0.6];
			haloRect.origin.y = 64.0 - halfHaloHeight;
			[haloImage drawInRect:haloRect fromRect:haloFromRect operation:NSCompositeSourceOver fraction:0.4];
			haloRect.origin.y = 96.0 - halfHaloHeight;
			[haloImage drawInRect:haloRect fromRect:haloFromRect operation:NSCompositeSourceOver fraction:0.2];
			
			[tempImage unlockFocus];
			
			[[NSWorkspace sharedWorkspace] setIcon:tempImage forFile:path options:NSExcludeQuickDrawElementsIconCreationOption];
		}
	}
	
	[self _fileDropped];
	
	return filenames;
}

- (void)_fileDropped
{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self.hotBorder setOpaqueToMouseEvents:NO];
		self.hotBorder = nil;
	});
}

- (void)_receivedData:(NSData*)data
{
	DebugLog(@"received data %ld", [data length]);
	_totalDataLength += [data length];
	[_unarchiver writeData:data];
}

- (void)_receiverDataTransferCompleted
{
	DebugLog(@"file transfer completed");
	[_unarchiver close];
	_unarchiver = nil;
	[self _completeTransferIfPossible];
	[super _receiverDataTransferCompleted];
}

@end

