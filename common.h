/*
 *  common.h
 *  Teleport
 *
 *  Created by JuL on Thu Dec 04 2003.
 *  Copyright (c) 2003-2005 abyssoft. All rights reserved.
 *
 */

/* Debug */
#define DEBUG_GENERAL 0
#define DEBUG_TRANSFERS 0

#define DebugLog(logString, args...) \
if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableLogging"]) \
NSLog(logString , ##args)

/* Macros */
#define DELETE(obj) if(obj) {[obj release]; obj=nil;}
#define PRINT_ME DebugLog(@"%@: %s", self, __PRETTY_FUNCTION__);
#define PRINT_ME_IF(cond) do{if(cond) DebugLog(@"%@: %s", self, __PRETTY_FUNCTION__);}while(0)

/* Constants */
#define RV_SERVICE @"_teleport._tcp"

#define LEFT_MOUSE_BUTTON 0
#define RIGHT_MOUSE_BUTTON 1
#define OTHER_MOUSE_BUTTON 2
