//
//  TPBonjourController.h
//  teleport
//
//  Created by JuL on 30/01/05.
//  Copyright 2003-2005 abyssoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TPBonjourController : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
{
	NSNetService * _publishService;
	NSNetServiceBrowser * _browseService;
	NSMutableDictionary * _browsers;
	NSMutableSet *_services;
	NSMutableDictionary * _namesToIdentifiersDict;
}

+ (TPBonjourController*)defaultController;

- (void)publishWithPort:(int)port;
- (void)updateTXTRecordOfPublishService;

- (void)unpublish;

- (void)browse;
- (void)stopBrowsing;

@end
