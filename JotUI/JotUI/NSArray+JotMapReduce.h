//
//  NSArray+MapReduce.h
//  Loose Leaf
//
//  Created by Adam Wulf on 6/18/12.
//  Copyright (c) 2012 Milestone Made, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSArray (JotMapReduce)
- (NSArray*)jotMap:(id (^)(id obj, NSUInteger index))mapfunc;
- (NSArray*)jotMapWithSelector:(SEL)mapSelector;
- (id)jotReduce:(id (^)(id obj, NSUInteger index, id accum))reducefunc;
- (BOOL)containsObjectIdenticalTo:(id)anObject;
@end
