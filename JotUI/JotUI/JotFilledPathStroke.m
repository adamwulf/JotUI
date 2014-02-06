//
//  JotFilledPathStroke.m
//  JotUI
//
//  Created by Adam Wulf on 2/5/14.
//  Copyright (c) 2014 Adonit. All rights reserved.
//

#import "JotFilledPathStroke.h"
#import "FilledPathElement.h"

@implementation JotFilledPathStroke{
    UIBezierPath* path;
    // cache the hash, since it's expenseive to calculate
    NSUInteger hashCache;
    // texture
    JotGLTexture* pathTexture;
    // segments
    NSMutableArray* segments;
}

@synthesize texture;
@synthesize segments;

/**
 * create an empty stroke with the input texture
 */
-(id) initWithPath:(UIBezierPath*)_path andP1:(CGPoint)_p1 andP2:(CGPoint)_p2 andP3:(CGPoint)_p3 andP4:(CGPoint)_p4{
    if(self = [super init]){
        hashCache = 1;
        path = _path;
        segments = [NSMutableArray arrayWithObject:[FilledPathElement elementWithPath:_path andP1:_p1 andP2:_p2 andP3:_p3 andP4:_p4]];
    }
    return self;
}

-(CGRect) bounds{
    return [path bounds];
}

/**
 * will add the input bezier element to the end of the stroke
 */
-(void) addElement:(AbstractBezierPathElement*)element{
    @throw [NSException exceptionWithName:@"FilledPathStroke Exception" reason:@"cannot add element to filled path stroke" userInfo:nil];
}

/**
 * remove a segment from the stroke
 */
-(void) removeElementAtIndex:(NSInteger)index{
    @throw [NSException exceptionWithName:@"FilledPathStroke Exception" reason:@"cannot remove element of filled path stroke" userInfo:nil];
}

/**
 * cancel the stroke and notify the delegate
 */
-(void) cancel{
    @throw [NSException exceptionWithName:@"FilledPathStroke Exception" reason:@"cannot cancel filled path stroke" userInfo:nil];
}



#pragma mark - PlistSaving

-(NSDictionary*) asDictionary{
    return [NSDictionary dictionaryWithObjectsAndKeys:@"JotFilledPathStroke", @"class",
            nil];
}

-(id) initFromDictionary:(NSDictionary*)dictionary{
    if(self = [super init]){
        hashCache = 1;
    }
    return self;
}


#pragma mark - hashing and equality

-(void) updateHashWithObject:(NSObject*)obj{
    NSUInteger prime = 31;
    hashCache = prime * hashCache + [obj hash];
}

-(NSUInteger) hash{
    return hashCache;
}

-(NSString*) uuid{
    return [NSString stringWithFormat:@"%u", [self hash]];
}

-(BOOL) isEqual:(id)object{
    return self == object || [self hash] == [object hash];
}


@end
