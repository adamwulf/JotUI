//
//  JotFilledPathStroke.m
//  JotUI
//
//  Created by Adam Wulf on 2/5/14.
//  Copyright (c) 2014 Milestone Made. All rights reserved.
//

#import "JotFilledPathStroke.h"
#import "FilledPathElement.h"
#import "AbstractBezierPathElement.h"
#import "AbstractBezierPathElement-Protected.h"


@implementation JotFilledPathStroke {
    UIBezierPath* _path;
}

/**
 * create an empty stroke with the input texture
 */
- (id)initWithPath:(UIBezierPath*)path andP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4 andSize:(CGSize)size {
    if (self = [self init]) {
        _path = path;
        [segments addObject:[FilledPathElement elementWithPath:_path andP1:p1 andP2:p2 andP3:p3 andP4:p4 andSize:(CGSize)size]];
        [self updateHashWithObject:[segments firstObject]];
    }
    return self;
}

- (CGRect)bounds {
    return [[segments firstObject] bounds];
}

- (JotGLTexture*)texture {
    return nil;
}

/**
 * will add the input bezier element to the end of the stroke
 */
- (void)addElement:(AbstractBezierPathElement*)element {
    @throw [NSException exceptionWithName:@"FilledPathStroke Exception" reason:@"cannot add element to filled path stroke" userInfo:nil];
}

// NOTE: we allow removeElement: to pass through to the parent class
// this method is used during validateUndoState to draw strokes to the
// backing layer, not to modify the strokes state

/**
 * cancel the stroke and notify the delegate
 */
- (void)cancel {
    @throw [NSException exceptionWithName:@"FilledPathStroke Exception" reason:@"cannot cancel filled path stroke" userInfo:nil];
}


#pragma mark - PlistSaving

- (NSDictionary*)asDictionary {
    return [NSDictionary dictionaryWithObjectsAndKeys:@"JotFilledPathStroke", @"class",
                                                      [self.segments jotMapWithSelector:@selector(asDictionary)], @"segments",
                                                      nil];
}

- (id)initFromDictionary:(NSDictionary*)dictionary {
    if (self = [super init]) {
        hashCache = 1;
        segments = [NSMutableArray arrayWithArray:[[dictionary objectForKey:@"segments"] jotMap:^id(id obj, NSUInteger index) {
            NSString* className = [obj objectForKey:@"class"];
            Class class = NSClassFromString(className);
            // pass in target scale
            [obj setObject:[dictionary objectForKey:@"scale"] forKey:@"scale"];
            AbstractBezierPathElement* segment = [[class alloc] initFromDictionary:obj];
            [self updateHashWithObject:segment];
            return segment;
        }]];
    }
    return self;
}


#pragma mark - hashing and equality

- (void)updateHashWithObject:(NSObject*)obj {
    NSUInteger prime = 31;
    hashCache = prime * hashCache + [obj hash];
}

- (NSUInteger)hash {
    return hashCache;
}

- (NSString*)uuid {
    return [NSString stringWithFormat:@"%lu", (unsigned long)[self hash]];
}

- (BOOL)isEqual:(id)object {
    return self == object || [self hash] == [object hash];
}


@end
