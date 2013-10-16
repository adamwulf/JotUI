//
//  AbstractSegment.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import "AbstractBezierPathElement.h"
#import "AbstractBezierPathElement-Protected.h"
#import "UIColor+JotHelper.h"
#import "JotUI.h"

#define kAbstractMethodException [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil]

int printOglError(char *file, int line)
{
    
    GLenum glErr;
    int    retCode = 0;
    
    glErr = glGetError();
    if (glErr != GL_NO_ERROR)
    {
        NSLog(@"glError in file %s @ line %d: %d\n",
               file, line, glErr);
        retCode = glErr;
    }
    return retCode;
}


@implementation AbstractBezierPathElement{
    JotBufferManager* bufferManager;
}

@synthesize startPoint;
@synthesize width;
@synthesize color;
@synthesize rotation;
@synthesize bufferManager;

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

-(CGFloat) angleOfStart{
    @throw kAbstractMethodException;
}

-(CGFloat) angleOfEnd{
    @throw kAbstractMethodException;
}

-(CGRect) bounds{
    @throw kAbstractMethodException;
}

-(CGPoint) endPoint{
    @throw kAbstractMethodException;
}

-(void) adjustStartBy:(CGPoint)adjustment{
    @throw kAbstractMethodException;
}

/**
 * return the number of vertices to use per
 * step. this should be a multiple of 3,
 * since rendering is using GL_TRIANGLES
 */
-(NSInteger) numberOfVerticesPerStep{
    return 1;
}

/**
 * the ideal number of steps we should take along
 * this line to render it with vertex points
 */
-(NSInteger) numberOfSteps{
    return MAX(floorf([self lengthOfElement] / kBrushStepSize), 1);
}

/**
 * returns the total number of vertices for this element
 */
-(NSInteger) numberOfVertices{
    return [self numberOfSteps] * [self numberOfVerticesPerStep];
}

-(NSInteger) numberOfBytesGivenPreviousElement:(AbstractBezierPathElement *)previousElement{
    @throw kAbstractMethodException;
}

-(void) validateDataGivenPreviousElement:(AbstractBezierPathElement*)previousElement{
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
-(struct ColorfulVertex*) generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale{
    @throw kAbstractMethodException;
}


/**
 * will calculate a square of coordinates that can
 * be filled with the texture of the brush.
 * results are returned through pointArr
 */
-(void) arrayOfPositionsForPoint:(CGPoint)point
                            andWidth:(CGFloat)stepWidth
                         andRotation:(CGFloat)stepRotation
                            outArray:(CGPoint*)pointArr{
    point.x = point.x * scaleOfVertexBuffer;
    point.y = point.y * scaleOfVertexBuffer;
    
    CGRect rect = CGRectMake(point.x - stepWidth/2, point.y - stepWidth/2, stepWidth, stepWidth);
    
    CGPoint topLeft  = rect.origin; topLeft.y += rect.size.width;
    CGPoint topRight = rect.origin; topRight.y += rect.size.width; topRight.x += rect.size.width;
    CGPoint botLeft  = rect.origin;
    CGPoint botRight = rect.origin; botRight.x += rect.size.width;
    
    // translate + rotate + translate each point to rotate it
    CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(point.x, point.y);
    CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(stepRotation);
    CGAffineTransform customRotation = CGAffineTransformConcat(CGAffineTransformConcat( CGAffineTransformInvert(translateTransform), rotationTransform), translateTransform);
    
    topLeft = CGPointApplyAffineTransform(topLeft, customRotation);
    topRight = CGPointApplyAffineTransform(topRight, customRotation);
    botLeft = CGPointApplyAffineTransform(botLeft, customRotation);
    botRight = CGPointApplyAffineTransform(botRight, customRotation);
    
    pointArr[0] = topLeft;
    pointArr[1] = topRight;
    pointArr[2] = botLeft;
    pointArr[3] = botRight;
    pointArr[4] = topRight;
    pointArr[5] = botLeft;
}

-(CGFloat) angleBetweenPoint:(CGPoint) point1 andPoint:(CGPoint)point2 {
    // Provides a directional bearing from point2 to the given point.
    // standard cartesian plain coords: Y goes up, X goes right
    // result returns radians, -180 to 180 ish: 0 degrees = up, -90 = left, 90 = right
    return atan2f(point1.y - point2.y, point1.x - point2.x) + M_PI_2;
}

-(void) loadDataIntoVBOIfNeeded{
   // noop
}

-(BOOL) bind{
    return NO;
}

-(void) unbind{
    @throw kAbstractMethodException;
}

-(void) draw{
    if([self bind]){
        // VBO
        glDrawArrays(GL_POINTS, 0, [self numberOfSteps] * [self numberOfVerticesPerStep]);
        [self unbind];
    }
}


#pragma mark - PlistSaving

-(NSDictionary*) asDictionary{
    return [NSDictionary dictionaryWithObjectsAndKeys:NSStringFromClass([self class]), @"class",
            [NSNumber numberWithFloat:startPoint.x], @"startPoint.x",
            [NSNumber numberWithFloat:startPoint.y], @"startPoint.y",
            [NSNumber numberWithFloat:width], @"width",
            (color ? [color asDictionary] : [NSDictionary dictionary]), @"color",
            [NSNumber numberWithFloat:rotation], @"rotation",
            [NSNumber numberWithFloat:scaleOfVertexBuffer], @"scaleOfVertexBuffer", nil];
}

-(id) initFromDictionary:(NSDictionary*)dictionary{
    self = [super init];
    if (self) {
        startPoint = CGPointMake([[dictionary objectForKey:@"startPoint.x"] floatValue], [[dictionary objectForKey:@"startPoint.y"] floatValue]);
        width = [[dictionary objectForKey:@"width"] floatValue];
        color = [UIColor colorWithDictionary:[dictionary objectForKey:@"color"]];
        rotation = [[dictionary objectForKey:@"rotation"] floatValue];
        scaleOfVertexBuffer = [[dictionary objectForKey:@"scaleOfVertexBuffer"] floatValue];
    }
    return self;
}

@end
