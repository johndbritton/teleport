/*
 *  TPHostSnapping.h
 *  teleport
 *
 *  Created by JuL on 11/05/05.
 *  Copyright 2005 abyssoft. All rights reserved.
 *
 */

typedef NS_OPTIONS(NSUInteger, TPSide) {
	TPUndefSide		= 0,
	TPRightSide		= 1 << 0,
	TPBottomSide	= 1 << 1,
	TPLeftSide		= 1 << 2,
	TPTopSide		= 1 << 3
} ;

float TPSquaredDistance(NSRect rect1, NSRect rect2);
float TPGluedRect(NSRect * outGluedRect, TPSide * outSide, NSRect fixedRect, NSRect mobileRect, TPSide excludedSides);
NSRect TPRectShiftedOnSide(NSRect rect, TPSide side, float amount);
