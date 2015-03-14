//
//  TPFileSerialization.m
//  Streams
//
//  Created by Julien Robert on 09/10/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import "TPFileSerialization.h"

NSString * TPFileArchiverNameKey = @"TPFileArchiverName";
NSString * TPFileArchiverTypeKey = @"TPFileArchiverType";

@implementation TPFileArchiver

+ (NSDictionary*)environment
{
	return @{@"LANG": @"en_US.UTF-8",
			@"LC_CTYPE": @"en_US.UTF-8"};
}

- (instancetype) initForReadingFilesAtPaths:(NSArray*)paths delegate:(id<TPFileArchiverDelegate>)delegate
{
    self = [super init];
    
    _delegate = delegate;
    _paths = paths;
	
    _readPipe = [[NSPipe alloc] init];
    
    _readTask = [[NSTask alloc] init];
    [_readTask setLaunchPath:@"/usr/bin/tar"];
	
	NSMutableArray * arguments = [NSMutableArray arrayWithObjects:@"cz", @"-", nil];
	NSEnumerator * pathsEnum = [paths objectEnumerator];
	NSString * commonParentPath = nil;
	NSString * path;
	
	while((path = [pathsEnum nextObject]) != nil) {
		if(commonParentPath == nil) {
			commonParentPath = [path stringByDeletingLastPathComponent];
		}
		else if(![commonParentPath isEqual:[path stringByDeletingLastPathComponent]]) {
			continue;
		}
		
		[arguments addObject:[path lastPathComponent]];
	}	
	
    [_readTask setArguments:arguments];
	[_readTask setEnvironment:[TPFileArchiver environment]];
    [_readTask setCurrentDirectoryPath:commonParentPath];
    [_readTask setStandardOutput:_readPipe];
    
    _readFileHandle = [_readPipe fileHandleForReading];
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileHandleDidReadData:) name:NSFileHandleReadCompletionNotification object:_readFileHandle];
    
    return self;
}


- (NSArray*)representedFiles
{
	NSMutableArray * representedFiles = [NSMutableArray array];
	
	NSEnumerator * pathsEnum = [_paths objectEnumerator];
	NSString * path;
	
	while((path = [pathsEnum nextObject]) != nil) {
		NSDictionary * fileDict = [[NSDictionary alloc] initWithObjectsAndKeys:
								   [path lastPathComponent], TPFileArchiverNameKey,
								   [[NSWorkspace sharedWorkspace] typeOfFile:path error:NULL], TPFileArchiverTypeKey,
								   nil];
		[representedFiles addObject:fileDict];
	}		
	
	return representedFiles;
}

- (void)startReading
{
    [_readTask launch];
    [_readFileHandle readInBackgroundAndNotify];
}

- (void)continueReading
{
	[_readFileHandle readInBackgroundAndNotify];
}

- (void)fileHandleDidReadData:(NSNotification*)notification
{
    NSData * data = [notification userInfo][NSFileHandleNotificationDataItem];
    if([data length] > 0) {
        [_delegate fileArchiver:self hasDataAvailable:data];
    }
    else {
        [_delegate fileArchiverDidCompleteReading:self];
    }
}

@end

@implementation TPFileUnarchiver

- (instancetype) initForWritingAtPath:(NSString*)path
{
    self = [super init];
    
    _writePipe = [[NSPipe alloc] init];
    
    _writeTask = [[NSTask alloc] init];
    [_writeTask setLaunchPath:@"/usr/bin/tar"];
    [_writeTask setArguments:@[@"xz", @"-C", path]];
	[_writeTask setEnvironment:[TPFileArchiver environment]];
    [_writeTask setStandardInput:_writePipe];
    
    _writeFileHandle = [_writePipe fileHandleForWriting];
    
    return self;
}


- (void)startWriting
{
    [_writeTask launch];
}

- (void)close
{
	[_writeFileHandle closeFile];
	[_writeTask waitUntilExit];
}

- (void)writeData:(NSData*)data
{
    [_writeFileHandle writeData:data];
}

@end