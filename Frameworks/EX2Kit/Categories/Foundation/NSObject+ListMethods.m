//
//  NSObject+ListMethods.m
//  EX2Kit
//
//  Created by Ben Baron on 2/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "NSObject+ListMethods.h"
#import <objc/runtime.h>

@implementation NSObject (ListMethods)

- (void)logMethods
{
	int i=0;
	unsigned int mc = 0;
	Method * mlist = class_copyMethodList(object_getClass(self), &mc);
	NSLog(@"%d methods", mc);
	for(i=0;i<mc;i++)
		NSLog(@"Method no #%d: %s", i, sel_getName(method_getName(mlist[i])));
}

@end
