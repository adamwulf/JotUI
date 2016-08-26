//
//  NSMutableArray+RemoveSingle.m
//  JotUI
//
//  Created by Adam Wulf on 10/24/14.
//  Copyright (c) 2014 Milestone Made. All rights reserved.
//

#import "NSMutableArray+RemoveSingle.h"


@implementation NSMutableArray (RemoveSingle)

- (void)removeSingleObject:(id)obj {
    NSUInteger idx = [self indexOfObject:obj];
    if (idx != NSNotFound) {
        [self removeObjectAtIndex:idx];
    }
}

@end
