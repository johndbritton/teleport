//
//  TPFileSerialization.h
//  Streams
//
//  Created by Julien Robert on 09/10/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString * TPFileArchiverNameKey;
extern NSString * TPFileArchiverTypeKey;

@class TPFileArchiver;

@protocol TPFileArchiverDelegate <NSObject>

- (void)fileArchiver:(TPFileArchiver*)archiver hasDataAvailable:(NSData*)data;
- (void)fileArchiverDidCompleteReading:(TPFileArchiver*)archiver;

@end

@interface TPFileArchiver : NSObject
{
    id <TPFileArchiverDelegate> _delegate;
    NSArray * _paths;
    NSTask * _readTask;
    NSPipe * _readPipe;
    NSFileHandle * _readFileHandle;
}

- (instancetype) initForReadingFilesAtPaths:(NSArray*)paths delegate:(id<TPFileArchiverDelegate>)delegate NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, copy) NSArray *representedFiles;

- (void)startReading;
- (void)continueReading;

@end

@interface TPFileUnarchiver : NSObject
{
    NSTask * _writeTask;
    NSPipe * _writePipe;
    NSFileHandle * _writeFileHandle;    
}

- (instancetype) initForWritingAtPath:(NSString*)path NS_DESIGNATED_INITIALIZER;

- (void)startWriting;
- (void)close;

- (void)writeData:(NSData*)data;

@end
