//
//  TPTableView.m
//  teleport
//
//  Created by JuL on 12/05/06.
//  Copyright 2006 abyssoft. All rights reserved.
//

#import "TPTableView.h"


@implementation TPTableView

- (void)keyDown:(NSEvent*)event
{
	if(_delegate && [_delegate respondsToSelector:@selector(tableView:handleKeyDown:)]) {
		if([_delegate tableView:self handleKeyDown:event])
			return;
	}
	
	[super keyDown:event];
}

@end
