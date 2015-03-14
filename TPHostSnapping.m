/*
 *  TPHostSnapping.c
 *  teleport
 *
 *  Created by JuL on 11/05/05.
 *  Copyright 2005 abyssoft. All rights reserved.
 *
 */

#include "TPHostSnapping.h"

float TPSquaredDistance(NSRect rect1, NSRect rect2) {
	NSPoint point1 = rect1.origin;
	NSPoint point2 = rect2.origin;
	float dx = point1.x - point2.x;
	float dy = point1.y - point2.y;
	return dx*dx+dy*dy;
}

float TPGluedRect(NSRect * outGluedRect, TPSide * outSide, NSRect fixedRect, NSRect mobileRect, TPSide excludedSides)
{
	int s = 0;
	NSRect gluedRect[4];
	TPSide side[4];
	
	/* Right */
	side[s] = TPRightSide;
	gluedRect[s] = mobileRect;
	gluedRect[s].origin.x = NSMaxX(fixedRect);
	gluedRect[s].origin.y = MIN(NSMaxY(fixedRect), MAX(NSMinY(fixedRect) - NSHeight(mobileRect), gluedRect[s].origin.y));
	
	/* Left */
	side[++s] = TPLeftSide;
	gluedRect[s] = mobileRect;
	gluedRect[s].origin.x = NSMinX(fixedRect) - NSWidth(mobileRect);
	gluedRect[s].origin.y = gluedRect[s-1].origin.y;
	
	/* Top */
	side[++s] = TPTopSide;
	gluedRect[s] = mobileRect;
	gluedRect[s].origin.y = NSMaxY(fixedRect);
	gluedRect[s].origin.x = MIN(NSMaxX(fixedRect), MAX(NSMinX(fixedRect) - NSWidth(mobileRect), gluedRect[s].origin.x));
	
	/* Bottom */
	side[++s] = TPBottomSide;
	gluedRect[s] = mobileRect;
	gluedRect[s].origin.y = NSMinY(fixedRect) - NSHeight(mobileRect);
	gluedRect[s].origin.x = gluedRect[s-1].origin.x;
	
	NSRect minGluedRect = NSZeroRect;
	float minDist = INFINITY;
	TPSide minSide = TPLeftSide;
	
	for(s=0; s<4; s++) {
		if((side[s] & excludedSides) == 0) {
			float dist = TPSquaredDistance(mobileRect, gluedRect[s]);
			if(dist < minDist) {
				minDist = dist;
				minSide = side[s];
				minGluedRect = gluedRect[s];
			}			
		}
	}
	
	if(outGluedRect != NULL)
		*outGluedRect = minGluedRect;
	if(outSide != NULL) {
		switch(minSide) {
			case TPRightSide:
			case TPLeftSide:
				if(NSMinY(mobileRect) >= NSMaxY(fixedRect))
					minSide |= TPTopSide;
				else if(NSMaxY(mobileRect) <= NSMinY(fixedRect))
					minSide |= TPBottomSide;
				break;
			case TPTopSide:
			case TPBottomSide:
				if(NSMinX(mobileRect) >= NSMaxX(fixedRect))
					minSide |= TPRightSide;
				else if(NSMaxX(mobileRect) <= NSMinX(fixedRect))
					minSide |= TPLeftSide;
				break;
			default:
				break;
		}
		
		*outSide = minSide;
	}
	
	if(NSIntersectsRect(fixedRect, mobileRect))
		return -minDist;
	else
		return minDist;
}

NSRect TPRectShiftedOnSide(NSRect rect, TPSide side, float amount)
{
	NSRect shiftedRect = rect;
	switch(side) {
		case TPRightSide:
			shiftedRect.origin.x += amount;
			break;
		case TPLeftSide:
			shiftedRect.origin.x -= amount;
			break;
		case TPTopSide:
			shiftedRect.origin.y += amount;
			break;
		case TPBottomSide:
			shiftedRect.origin.y -= amount;
			break;
		default:
			break;
	}
	return shiftedRect;
}
