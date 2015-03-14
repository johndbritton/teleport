//
//  TPMainController.h
//  Teleport
//
//  Created by JuL on Thu Dec 25 2003.
//  Copyright (c) 2003-2005 abyssoft. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef uint32_t CGSUInt32;

struct CPSProcessSerNum
{
	CGSUInt32 hi;
	CGSUInt32 lo;
};
typedef struct CPSProcessSerNum	CPSProcessSerNum;

@class TPNetworkConfigurationWatcher;

@interface TPMainController : NSObject
{
	CPSProcessSerNum _frontProcessNum;
	TPNetworkConfigurationWatcher * _networkConfigurationWatcher;
}

+ (TPMainController*)sharedController;

- (BOOL)canBeControlledByHostWithIdentifier:(NSString*)identifier;
- (BOOL)canControlHostWithIdentifier:(NSString*)identifier;

/* UI */
- (void)goFrontmost;
- (void)leaveFrontmost;
- (int)presentAlert:(NSAlert*)alert;

/* Version checking */
- (void)checkVersionFromNotification:(NSNotification*)notification;
- (void)checkVersionsAndConfirm:(BOOL)confirm;

@end
