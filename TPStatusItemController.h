//
//  TPStatusItemController.h
//  teleport
//
//  Created by JuL on 20/05/05.
//  Copyright 2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TPRemoteHost.h"

typedef NS_ENUM(NSInteger, TPStatus) {
	TPStatusIdle,
	TPStatusControlling,
	TPStatusControlled
} ;

@interface TPStatusItemController : NSObject
{
	NSStatusItem * _statusItem;
}

+ (TPStatusItemController*)defaultController;

@property (nonatomic) BOOL showStatusItem;

- (void)updateWithStatus:(TPStatus)status host:(TPRemoteHost*)host;

@end
