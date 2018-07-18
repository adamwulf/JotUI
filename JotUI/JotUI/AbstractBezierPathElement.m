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

// This value should change if we ever decide to change how strokes are rendered, which would
// cause them to need to re-calculate their cached vertex buffer
#define kJotUIRenderVersion 1


@implementation AbstractBezierPathElement

- (id)initWithStart:(CGPoint)point {
    if (self = [super init]) {
        _startPoint = point;
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
- (NSInteger)numberOfSteps {
    NSInteger ret = MAX(floorf(([self lengthOfElement] + [self previousExtraLengthWithoutDot]) / kBrushStepSize), 0);
    // if we are beginning the stroke, then we have 1 more
    // dot to begin the stroke. otherwise we skip the first dot
    // and pick up after kBrushStepSize
    if ([self followsMoveTo]) {
        ret += 1;
    }
    return ret;
}

/**
 * returns the total number of vertices for this element
 */
- (NSInteger)numberOfVertices {
    return [self numberOfSteps] * [self numberOfVerticesPerStep];
}

- (NSInteger)numberOfBytes {
    @throw kAbstractMethodException;
}

- (void)validateDataGivenPreviousElement:(AbstractBezierPathElement*)previousElement {
    if ([self renderVersion] != kJotUIRenderVersion && !_bakedPreviousElementProps) {
        _previousColor = previousElement.color;
        _previousWidth = previousElement.width;
        _previousRotation = previousElement.rotation;
        _previousExtraLengthWithoutDot = previousElement.extraLengthWithoutDot;
        _renderVersion = kJotUIRenderVersion;
        _followsMoveTo = [previousElement isKindOfClass:[MoveToPathElement class]];

        _scaleOfVertexBuffer = 0;
        _dataVertexBuffer = nil;
        _bakedPreviousElementProps = YES;
    }
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
- (struct ColorfulVertex*)generatedVertexArrayForScale:(CGFloat)scale {
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

- (void)draw {
    if ([self bind]) {
        // VBO
        [JotGLContext runBlock:^(JotGLContext* context) {
            if ([self numberOfSteps]) {
                [context drawPointCount:(int)([self numberOfSteps] * [self numberOfVerticesPerStep])
                            withProgram:[self glProgramForContext:context]];
            }
        }];
        [self unbind];
    }
}


#pragma mark - PlistSaving

- (NSDictionary*)asDictionary {
    return [NSDictionary dictionaryWithObjectsAndKeys:NSStringFromClass([self class]), @"class",
                                                      [NSNumber numberWithFloat:_startPoint.x], @"startPoint.x",
                                                      [NSNumber numberWithFloat:_startPoint.y], @"startPoint.y",
                                                      [NSNumber numberWithFloat:_rotation], @"rotation",
                                                      [NSNumber numberWithFloat:_width], @"width",
                                                      [NSNumber numberWithFloat:_stepWidth], @"stepWidth",
                                                      [NSNumber numberWithFloat:_extraLengthWithoutDot], @"extraLengthWithoutDot",
                                                      (_color ? [_color asDictionary] : [NSDictionary dictionary]), @"color",
                                                      [NSNumber numberWithFloat:_scaleOfVertexBuffer], @"scaleOfVertexBuffer",
                                                      [NSNumber numberWithBool:_followsMoveTo], @"followsMoveTo",
                                                      [NSNumber numberWithFloat:_previousExtraLengthWithoutDot], @"previousExtraLengthWithoutDot",
                                                      (_previousColor ? [_previousColor asDictionary] : [NSDictionary dictionary]), @"previousColor",
                                                      [NSNumber numberWithFloat:_previousWidth], @"previousWidth",
                                                      [NSNumber numberWithFloat:_previousRotation], @"previousRotation",
                                                      [NSNumber numberWithInteger:_renderVersion], @"renderVersion",
                                                      [NSNumber numberWithBool:_bakedPreviousElementProps], @"bakedPreviousElementProps",
                                                      nil];
}

- (id)initFromDictionary:(NSDictionary*)dictionary {
    self = [super init];
    if (self) {
        _startPoint = CGPointMake([[dictionary objectForKey:@"startPoint.x"] floatValue], [[dictionary objectForKey:@"startPoint.y"] floatValue]);
        _width = [[dictionary objectForKey:@"width"] floatValue];
        _rotation = [[dictionary objectForKey:@"rotation"] floatValue];
        _stepWidth = [[dictionary objectForKey:@"stepWidth"] floatValue] ?: .5;
        _extraLengthWithoutDot = [[dictionary objectForKey:@"extraLengthWithoutDot"] floatValue];
        _color = [UIColor colorWithDictionary:[dictionary objectForKey:@"color"]];
        _scaleOfVertexBuffer = [[dictionary objectForKey:@"scaleOfVertexBuffer"] floatValue];
        _followsMoveTo = [[dictionary objectForKey:@"followsMoveTo"] boolValue];
        _previousWidth = [[dictionary objectForKey:@"previousWidth"] floatValue];
        _previousRotation = [[dictionary objectForKey:@"previousRotation"] floatValue];
        _previousExtraLengthWithoutDot = [[dictionary objectForKey:@"previousExtraLengthWithoutDot"] floatValue] ?: .5;
        _previousColor = [UIColor colorWithDictionary:[dictionary objectForKey:@"previousColor"]];
        _renderVersion = [[dictionary objectForKey:@"renderVersion"] integerValue];
        _bakedPreviousElementProps = [[dictionary objectForKey:@"followsMoveTo"] boolValue];
    }
    return self;
}

#pragma mark - Scaling

- (void)scaleForWidth:(CGFloat)widthRatio andHeight:(CGFloat)heightRatio {
    _startPoint.x = _startPoint.x * widthRatio;
    _startPoint.y = _startPoint.y * heightRatio;
}

@end
