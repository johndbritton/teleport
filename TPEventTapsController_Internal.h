/*
 *  TPEventTapsController_Internal.h
 *  teleport
 *
 *  Created by Julien Robert on 01/08/07.
 *  Copyright 2007 abyssoft. All rights reserved.
 *
 */

#import "TPEventTapsController.h"

extern CGEventTimestamp CGSCurrentEventTimestamp(void);

@interface TPEventTapsController (Private)

+ (NSString*)_eventNameFromType:(CGEventType)type;
- (void)_postEvent:(CGEventRef)event;

@end
