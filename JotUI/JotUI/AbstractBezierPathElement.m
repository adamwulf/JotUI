//
//  AbstractSegment.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import "AbstractBezierPathElement.h"


#define kAbstractMethodException [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil]

@implementation AbstractBezierPathElement

@synthesize startPoint;
@synthesize width;
@synthesize color;

-(id) initWithStart:(CGPoint)point{
    if(self = [super init]){
        startPoint = point;
    }
    return self;
}

/**
 * the length of the drawn segment. if it is a
 * curve, then it is the travelled distance along
 * the curve, not the linear distance between start
 * and end points
 */
-(CGFloat) lengthOfElement{
    @throw kAbstractMethodException;
}

/**
 * return the number of vertices to use per
 * step. this should be a multiple of 3,
 * since rendering is using GL_TRIANGLES
 */
-(NSInteger) numberOfVerticesPerStep{
    return 6;
}

/**
 * the ideal number of steps we should take along
 * this line to render it with vertex points
 */
-(NSInteger) numberOfSteps{
    return MAX(floorf([self lengthOfElement] / kBrushStepSize), 1);
}

/**
 * this will return an array of vertex structs
 * that we can send to OpenGL to draw. Ideally,
 * subclasses will generate this array once to save
 * CPU cycles when drawing.
 *
 * the generated vertex array should be stored in
 * vertexBuffer ivar
 */
-(struct Vertex*) generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale{
    @throw kAbstractMethodException;
}

/**
 * make sure to free the generated vertex info
 */
-(void) dealloc{
    if(vertexBuffer){
        free(vertexBuffer);
        vertexBuffer = nil;
    }
}

@end
