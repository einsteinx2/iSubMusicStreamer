//
//  UITableView+Shadows.m
//  EX2Kit
//
//  Created by Benjamin Baron on 4/23/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "UITableView+Shadows.h"
#import "UIView+Tools.h"

@implementation UITableView (Shadows)

#define SHADOW_ALPHA 0.25
#define SHADOW_WIDTH 10.0

- (void)addFooterShadow
{
	if (!self.tableFooterView)
		self.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.width, 0.)];
	
	[self.tableFooterView addBottomShadowWithWidth:SHADOW_WIDTH alpha:SHADOW_ALPHA];
}

- (void)removeFooterShadow
{
	[self.tableFooterView removeBottomShadow];
}

- (void)addHeaderShadow
{
	if (!self.tableHeaderView)
		self.tableHeaderView = [[UIView alloc] init];
	
	[self.tableFooterView addTopShadowWithWidth:SHADOW_WIDTH alpha:SHADOW_ALPHA];
}

- (void)removeHeaderShadow
{
	[self.tableHeaderView removeTopShadow];
}

@end
