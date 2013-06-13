//
//  DotSegment.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import "MoveToPathElement.h"
#import "AbstractBezierPathElement-Protected.h"

@implementation MoveToPathElement

-(id) initWithMoveTo:(CGPoint)_point{
    if(self = [super initWithStart:_point]){
        // noop
    }
    return self;
}

+(id) elementWithMoveTo:(CGPoint)point{
    return [[MoveToPathElement alloc] initWithMoveTo:point];
}

/**
 * we're just 1 point, so we have zero length
 */
-(CGFloat) lengthOfElement{
    return 0;
}

-(CGFloat) angleOfStart{
    return 0;
}

-(CGFloat) angleOfEnd{
    return 0;
}


/**
 * only 1 step to show our single point
 */
-(NSInteger) numberOfSteps{
    return 0;
}

-(int) numberOfBytes{
    return 0;
}


-(struct Vertex*) generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale{
    return NULL;
}

#pragma mark - LineToPathElement subclass

/**
 * return meaningful values so that the LineToPathElement class
 * will generate a successful vertex array for us
 */
-(CGFloat) widthOfPreviousElement:(AbstractBezierPathElement*)previousElement{
    return self.width;
}

-(UIColor*) colorOfPreviousElement:(AbstractBezierPathElement*)previousElement{
    return self.color;
}


@end
