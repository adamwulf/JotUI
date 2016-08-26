//
//  AbstractSegment.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import "AbstractBezierPathElement.h"
#import "AbstractBezierPathElement-Protected.h"
#import "UIColor+JotHelper.h"
#import "JotUI.h"
#import "JotGLColorlessPointProgram.h"


@implementation AbstractBezierPathElement {
    JotBufferManager* bufferManager;
}

@synthesize stepWidth;
@synthesize rotation;
@synthesize startPoint;
@synthesize width;
@synthesize color;
@synthesize bufferManager;
@synthesize extraLengthWithoutDot;

- (id)initWithStart:(CGPoint)point {
    if (self = [super init]) {
        startPoint = point;
    }
    return self;
}

- (int)fullByteSize {
    @throw kAbstractMethodException;
}

/**
 * the length of the drawn segment. if it is a
 * curve, then it is the travelled distance along
 * the curve, not the linear distance between start
 * and end points
 */
- (CGFloat)lengthOfElement {
    @throw kAbstractMethodException;
}

- (CGFloat)angleOfStart {
    @throw kAbstractMethodException;
}

- (CGFloat)angleOfEnd {
    @throw kAbstractMethodException;
}

- (CGRect)bounds {
    @throw kAbstractMethodException;
}

- (CGPoint)endPoint {
    @throw kAbstractMethodException;
}

- (void)adjustStartBy:(CGPoint)adjustment {
    @throw kAbstractMethodException;
}

/**
 * return the number of vertices to use per
 * step. this should be a multiple of 3,
 * since rendering is using GL_TRIANGLES
 */
- (NSInteger)numberOfVerticesPerStep {
    return 1;
}

/**
 * the ideal number of steps we should take along
 * this line to render it with vertex points
 */
- (NSInteger)numberOfStepsGivenPreviousElement:(AbstractBezierPathElement*)previousElement {
    NSInteger ret = MAX(floorf(([self lengthOfElement] + previousElement.extraLengthWithoutDot) / kBrushStepSize), 0);
    // if we are beginning the stroke, then we have 1 more
    // dot to begin the stroke. otherwise we skip the first dot
    // and pick up after kBrushStepSize
    if ([previousElement isKindOfClass:[MoveToPathElement class]]) {
        ret += 1;
    }
    return ret;
}

/**
 * returns the total number of vertices for this element
 */
- (NSInteger)numberOfVerticesGivenPreviousElement:(AbstractBezierPathElement*)previousElement {
    return [self numberOfStepsGivenPreviousElement:previousElement] * [self numberOfVerticesPerStep];
}

- (NSInteger)numberOfBytesGivenPreviousElement:(AbstractBezierPathElement*)previousElement {
    @throw kAbstractMethodException;
}

- (void)validateDataGivenPreviousElement:(AbstractBezierPathElement*)previousElement {
    @throw kAbstractMethodException;
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
- (struct ColorfulVertex*)generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale {
    @throw kAbstractMethodException;
}

- (UIBezierPath*)bezierPathSegment {
    @throw kAbstractMethodException;
}


- (CGFloat)angleBetweenPoint:(CGPoint)point1 andPoint:(CGPoint)point2 {
    // Provides a directional bearing from point2 to the given point.
    // standard cartesian plain coords: Y goes up, X goes right
    // result returns radians, -180 to 180 ish: 0 degrees = up, -90 = left, 90 = right
    return atan2f(point1.y - point2.y, point1.x - point2.x) + M_PI_2;
}

- (void)loadDataIntoVBOIfNeeded {
    // noop
}

- (BOOL)bind {
    return NO;
}

- (void)unbind {
    @throw kAbstractMethodException;
}

- (JotGLProgram*)glProgramForContext:(JotGLContext*)context {
    return [context colorlessPointProgram];
}

- (void)drawGivenPreviousElement:(AbstractBezierPathElement*)previousElement {
    if ([self bind]) {
        // VBO
        [JotGLContext runBlock:^(JotGLContext* context) {
            if ([self numberOfStepsGivenPreviousElement:previousElement]) {
                [context drawPointCount:(int)([self numberOfStepsGivenPreviousElement:previousElement] * [self numberOfVerticesPerStep])
                            withProgram:[self glProgramForContext:context]];
            }
        }];
        [self unbind];
    }
}


#pragma mark - PlistSaving

- (NSDictionary*)asDictionary {
    return [NSDictionary dictionaryWithObjectsAndKeys:NSStringFromClass([self class]), @"class",
                                                      [NSNumber numberWithFloat:startPoint.x], @"startPoint.x",
                                                      [NSNumber numberWithFloat:startPoint.y], @"startPoint.y",
                                                      [NSNumber numberWithFloat:rotation], @"rotation",
                                                      [NSNumber numberWithFloat:width], @"width",
                                                      [NSNumber numberWithFloat:stepWidth], @"stepWidth",
                                                      [NSNumber numberWithFloat:extraLengthWithoutDot], @"extraLengthWithoutDot",
                                                      (color ? [color asDictionary] : [NSDictionary dictionary]), @"color",
                                                      [NSNumber numberWithFloat:scaleOfVertexBuffer], @"scaleOfVertexBuffer", nil];
}

- (id)initFromDictionary:(NSDictionary*)dictionary {
    self = [super init];
    if (self) {
        startPoint = CGPointMake([[dictionary objectForKey:@"startPoint.x"] floatValue], [[dictionary objectForKey:@"startPoint.y"] floatValue]);
        width = [[dictionary objectForKey:@"width"] floatValue];
        rotation = [[dictionary objectForKey:@"rotation"] floatValue];
        stepWidth = [[dictionary objectForKey:@"stepWidth"] floatValue] ?: .5;
        extraLengthWithoutDot = [[dictionary objectForKey:@"extraLengthWithoutDot"] floatValue];
        color = [UIColor colorWithDictionary:[dictionary objectForKey:@"color"]];
        scaleOfVertexBuffer = [[dictionary objectForKey:@"scaleOfVertexBuffer"] floatValue];
    }
    return self;
}

#pragma mark - Scaling

- (void)scaleForWidth:(CGFloat)widthRatio andHeight:(CGFloat)heightRatio {
    startPoint.x = startPoint.x * widthRatio;
    startPoint.y = startPoint.y * heightRatio;
}

@end
