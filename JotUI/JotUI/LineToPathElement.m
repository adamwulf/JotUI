//
//  LineToPathElement.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import "LineToPathElement.h"
#import "UIColor+JotHelper.h"

@implementation LineToPathElement

@synthesize lineTo;

-(id) initWithStart:(CGPoint)start andLineTo:(CGPoint)_point{
    if(self = [super initWithStart:start]){
        lineTo = _point;
    }
    return self;
}

+(id) elementWithStart:(CGPoint)start andLineTo:(CGPoint)point{
    return [[LineToPathElement alloc] initWithStart:start andLineTo:point];
}

/**
 * the distance between the start and end points
 */
-(CGFloat) lengthOfElement{
    return sqrtf((lineTo.x - startPoint.x) * (lineTo.x - startPoint.x) + (lineTo.y - startPoint.y) * (lineTo.y - startPoint.y));
}



-(NSInteger) numberOfSteps{
    return 6;
}

/**
 * generate a vertex buffer array for all of the points
 * along this curve for the input scale.
 *
 * this method will cache the array for a single scale. if
 * a new scale is sent in later, then the cache will be rebuilt
 * for the new scale.
 *
 * for any given scale, the number of vertexes are the exact same.
 * for a larger scale, the points are spread further apart and the
 * width of the vertex increased.
 *
 * in this way, a high resolution screen, which twice the width and height
 * will get the same number of vertexes in their scaled respective locations
 * with twice the width, so that it will show onscreen as simply higher
 * resolution content, even though its drawn with the same number of points
 */
-(struct Vertex*) generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale{
    // if we have a buffer generated and cached,
    // then just return that
    if(vertexBuffer && scaleOfVertexBuffer == scale){
        return vertexBuffer;
    }
    // malloc the memory for our buffer, if needed
    if(!vertexBuffer){
        vertexBuffer = (struct Vertex*) malloc([self numberOfSteps]*sizeof(struct Vertex));
    }
    
    // save our scale
    scaleOfVertexBuffer = scale;
    
    // Convert locations from Points to Pixels
	// Add points to the buffer so there are drawing points every X pixels
	int numberOfSteps = [self numberOfSteps];
    
    // now lets calculate the steps we need to adjust width
    CGFloat prevWidth =  [self widthOfPreviousElement:previousElement];
    CGFloat widthDiff = self.width - prevWidth;
    
    // next is the steps to adjust color
    GLubyte prevColor[4], myColor[4];
    short colorSteps[4];
    [[self colorOfPreviousElement:previousElement] getRGBAComponents:prevColor];
    [self.color getRGBAComponents:myColor];
    
    // calculate how much the RGBA will
    // need to change throughout the stroke
    colorSteps[0] = myColor[0] - prevColor[0];
    colorSteps[1] = myColor[1] - prevColor[1];
    colorSteps[2] = myColor[2] - prevColor[2];
    colorSteps[3] = myColor[3] - prevColor[3];
    
    // generate a single point vertex for each step
    // so that the stroke is essentially a series of dots
	for(int step = 0; step < numberOfSteps; step+=6) {
        // 0 <= t < 1
        CGFloat t = (CGFloat)step / (CGFloat)numberOfSteps;
        
        // calculate the point along the line
        CGPoint point = CGPointMake(startPoint.x + (lineTo.x - startPoint.x) * t,
                                    startPoint.y + (lineTo.y - startPoint.y) * t);
        
        
        // precalculate the color that we'll use for all
        // of the vertices for this step
        GLubyte calcColor[4];
        if(!self.color){
            // eraser
            calcColor[0] = 0;
            calcColor[1] = 0;
            calcColor[2] = 0;
            calcColor[3] = 255;
        }else{
            // normal brush
            // interpolate between starting and ending color
            calcColor[0] = prevColor[0] + colorSteps[0] * t;
            calcColor[1] = prevColor[1] + colorSteps[1] * t;
            calcColor[2] = prevColor[2] + colorSteps[2] * t;
            calcColor[3] = prevColor[3] + colorSteps[3] * t;
            // premultiply alpha
            calcColor[0] *= (vertexBuffer[step].Color[3] / 255.0);
            calcColor[1] *= (vertexBuffer[step].Color[3] / 255.0);
            calcColor[2] *= (vertexBuffer[step].Color[3] / 255.0);
        }
        
        NSArray* vertexPointArray = [self arrayOfPositionsForPoint:point
                                                          andWidth:prevWidth + widthDiff * t
                                                       andRotation:0];
        
        for(int innerStep = 0;innerStep < [vertexPointArray count];innerStep++){
            CGPoint stepPoint = [[vertexPointArray objectAtIndex:innerStep] CGPointValue];
            // Convert locations from Points to Pixels
            vertexBuffer[step + innerStep].Position[0] = stepPoint.x;
            vertexBuffer[step + innerStep].Position[1] = stepPoint.y;
            if(innerStep == 0){
                vertexBuffer[step + innerStep].Texture[0] = 0;
                vertexBuffer[step + innerStep].Texture[1] = 0;
            }else if(innerStep == 1){
                vertexBuffer[step + innerStep].Texture[0] = 1;
                vertexBuffer[step + innerStep].Texture[1] = 0;
            }else if(innerStep == 2){
                vertexBuffer[step + innerStep].Texture[0] = 0;
                vertexBuffer[step + innerStep].Texture[1] = 1;
            }else if(innerStep == 3){
                vertexBuffer[step + innerStep].Texture[0] = 1;
                vertexBuffer[step + innerStep].Texture[1] = 1;
            }else if(innerStep == 4){
                vertexBuffer[step + innerStep].Texture[0] = 1;
                vertexBuffer[step + innerStep].Texture[1] = 0;
            }else if(innerStep == 5){
                vertexBuffer[step + innerStep].Texture[0] = 0;
                vertexBuffer[step + innerStep].Texture[1] = 1;
            }
            // set colors to the array
            vertexBuffer[step + innerStep].Color[0] = calcColor[0];
            vertexBuffer[step + innerStep].Color[1] = calcColor[1];
            vertexBuffer[step + innerStep].Color[2] = calcColor[2];
            vertexBuffer[step + innerStep].Color[3] = calcColor[3];
        }
	}
    return vertexBuffer;
}

-(NSArray*) arrayOfPositionsForPoint:(CGPoint)point
                            andWidth:(CGFloat)stepWidth
                         andRotation:(CGFloat)stepRotation{
    point.x = point.x * scaleOfVertexBuffer;
    point.y = point.y * scaleOfVertexBuffer;
    
    CGRect rect = CGRectMake(point.x - stepWidth/2, point.y - stepWidth/2, stepWidth, stepWidth);
    
    CGPoint topLeft  = rect.origin;
    CGPoint topRight = rect.origin; topRight.x += rect.size.width;
    CGPoint botLeft  = rect.origin; botLeft.y += rect.size.width;
    CGPoint botRight = rect.origin; botRight.y += rect.size.width; botRight.x += rect.size.width;

    // TODO: rotation
    // translate + rotate + translate each point to rotate it
    
    NSMutableArray* outArray = [NSMutableArray array];
    [outArray addObject:[NSValue valueWithCGPoint:topLeft]];
    [outArray addObject:[NSValue valueWithCGPoint:topRight]];
    [outArray addObject:[NSValue valueWithCGPoint:botLeft]];
    [outArray addObject:[NSValue valueWithCGPoint:botRight]];
    [outArray addObject:[NSValue valueWithCGPoint:topRight]];
    [outArray addObject:[NSValue valueWithCGPoint:botLeft]];

    return outArray;
}


#pragma mark - For Subclasses

/**
 * these methods are easy to override by subclasses,
 * and will change how our vertex array is generated
 */
-(CGFloat) widthOfPreviousElement:(AbstractBezierPathElement*)previousElement{
    return previousElement.width;
}

-(UIColor*) colorOfPreviousElement:(AbstractBezierPathElement*)previousElement{
    return previousElement.color;
}

/**
 * helpful description when debugging
 */
-(NSString*)description{
    return [NSString stringWithFormat:@"[Line from: %f,%f  to: %f%f]", startPoint.x, startPoint.y, lineTo.x, lineTo.y];
}


@end
