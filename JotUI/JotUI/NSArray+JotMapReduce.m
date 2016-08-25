//
//  NSArray+MapReduce.m
//  Loose Leaf
//
//  Created by Adam Wulf on 6/18/12.
//  Copyright (c) 2012 Milestone Made, LLC. All rights reserved.
//

#import "NSArray+JotMapReduce.h"


@implementation NSArray (JotMapReduce)

//NSArray* arr            = [NSArray arrayWithObjects:@"Apple", @"Banana", @"Peanut", @"Tree", NULL];
//NSArray* butters        = [arr map:^(id obj, NSUInteger idx) {
//    return [NSString stringWithFormat:@"%@ Butter", obj];
//}];
- (NSArray*)jotMap:(id (^)(id obj, NSUInteger index))mapfunc {
    NSMutableArray* result = [[NSMutableArray alloc] init];
    NSUInteger index;
    for (index = 0; index < [self count]; index++) {
        id foo = mapfunc([self objectAtIndex:index], index);
        if (foo) {
            [result addObject:foo];
        }
    }
    return result;
}

- (NSArray*)jotMapWithSelector:(SEL)mapSelector {
    NSMutableArray* result = [[NSMutableArray alloc] init];
    NSUInteger index;
    for (index = 0; index < [self count]; index++) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [result addObject:[[self objectAtIndex:index] performSelector:mapSelector]];
#pragma clang diagnostic pop
    }
    return result;
}

//NSNumber* sum = [numbers reduce:^(id obj, NSUInteger idx, id accum) {
//    if( accum == NULL ) {
//        accum = [NSNumber numberWithInt:0];
//    }
//    return (id)[NSNumber numberWithInt:[obj intValue] + [accum intValue]];
//}];
- (id)jotReduce:(id (^)(id obj, NSUInteger index, id accum))reducefunc {
    id result = NULL;
    NSUInteger index;
    for (index = 0; index < [self count]; index++) {
        result = reducefunc([self objectAtIndex:index], index, result);
    }
    return result;
}

- (BOOL)containsObjectIdenticalTo:(id)anObject {
    for (id obj in self) {
        if (obj == anObject) {
            return YES;
        }
    }
    return NO;
}

@end
