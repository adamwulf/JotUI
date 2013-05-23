//
//  Marker.m
//  jotuiexample
//
//  Created by Adam Wulf on 12/18/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import "Marker.h"

@implementation Marker

-(id) initWithMinSize:(CGFloat)_minSize andMaxSize:(CGFloat)_maxSize andMinAlpha:(CGFloat)_minAlpha andMaxAlpha:(CGFloat)_maxAlpha{
    if(self = [super initWithMinSize:_minSize andMaxSize:_maxSize andMinAlpha:_minAlpha andMaxAlpha:_maxAlpha]){
        // noop
    }
    return self;
}

-(id) init{
    return [self initWithMinSize:22.0 andMaxSize:30.0 andMinAlpha:.3 andMaxAlpha:.5];
}

-(UIImage*) texture{
    return [UIImage imageNamed:@"Rectangle.png"];
}


/**
 * this Marker will rotate so that
 * it always faces the direction that
 * the stroke is travelling
 */
-(CGFloat) rotationForSegment:(AbstractBezierPathElement *)segment fromPreviousSegment:(AbstractBezierPathElement *)previousSegment{
    if([previousSegment isKindOfClass:[MoveToPathElement class]]){
        MoveToPathElement* moveTo = (MoveToPathElement*)previousSegment;
        moveTo.rotation = [segment angleOfStart] + M_PI_2;
    }
    return previousSegment.rotation + ([segment angleOfEnd] - [segment angleOfStart]);
}


@end
