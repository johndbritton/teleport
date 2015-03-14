//
//  TPFakeHostsGenerator.h
//  teleport
//
//  Created by Julien Robert on 01/05/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TPFakeHostsGenerator : NSObject
{
	NSTimer * _timer;
	NSMutableArray * _hosts;
}

- (void)run;

@end
