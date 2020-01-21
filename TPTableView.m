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
	if(self.delegate && [self.delegate respondsToSelector:@selector(tableView:handleKeyDown:)]) {
		if([(id)self.delegate tableView:self handleKeyDown:event])
			return;
	}
	
	[super keyDown:event];
}

@end
