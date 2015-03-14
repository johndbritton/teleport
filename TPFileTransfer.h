//
//  TPFileTransfer.h
//  teleport
//
//  Created by JuL on 14/02/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>

#import "TPTransfer.h"
#import "TPFileSerialization.h"

typedef NS_ENUM(NSInteger, TPFileTransferPhase) {
	TPFileTransferPromisePhase,
	TPFileTransferDataPhase
} ;

@class NSFilePromiseDragSource;

@interface TPOutgoingFileTransfer : TPOutgoingTransfer <TPFileArchiverDelegate>
{
	TPFileArchiver * _archiver;
	NSImage * _dragImage;
	NSPoint _dragImageLocation;
}

- (void)setFilePaths:(NSArray*)filePaths dragImage:(NSImage*)image location:(NSPoint)point;

@end

@interface TPIncomingFileTransfer : TPIncomingTransfer
{
	NSArray * _representedFiles;
	NSImage * _dragImage;
	NSPoint _dragImageLocation;
	NSMutableDictionary * _destinationPaths;
	float _progress;
	TPFileUnarchiver * _unarchiver;
}

@end

