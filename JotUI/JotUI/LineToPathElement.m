//
//  LineToPathElement.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import "LineToPathElement.h"
#import "UIColor+JotHelper.h"
#import "AbstractBezierPathElement-Protected.h"

@implementation LineToPathElement{
    // cache the hash, since it's expenseive to calculate
    NSUInteger hashCache;
}

@synthesize lineTo;

-(id) initWithStart:(CGPoint)start andLineTo:(CGPoint)_point{
    if(self = [super initWithStart:start]){
        lineTo = _point;
        NSUInteger prime = 31;
        hashCache = 1;
        hashCache = prime * hashCache + startPoint.x;
        hashCache = prime * hashCache + startPoint.y;
        hashCache = prime * hashCache + lineTo.x;
        hashCache = prime * hashCache + lineTo.y;
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


-(CGFloat) angleOfStart{
    return [self angleBetweenPoint:startPoint andPoint:lineTo];
}

-(CGFloat) angleOfEnd{
    return [self angleBetweenPoint:startPoint andPoint:lineTo];
}

-(CGRect) bounds{
    return CGRectInset(CGRectMake(MIN(startPoint.x, lineTo.x),
                                  MIN(startPoint.y, lineTo.y),
                                  fabs(startPoint.x - lineTo.x),
                                  fabs(startPoint.y - lineTo.y)), -width, -width);
}


-(int) numberOfBytes{
	int numberOfVertices = [self numberOfSteps] * [self numberOfVerticesPerStep];
    return numberOfVertices*sizeof(struct Vertex);
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
    if(dataVertexBuffer && scaleOfVertexBuffer == scale){
        return (struct Vertex*) dataVertexBuffer.bytes;
    }
    // Convert locations from Points to Pixels
	// Add points to the buffer so there are drawing points every X pixels
	int numberOfVertices = [self numberOfSteps] * [self numberOfVerticesPerStep];
    
    // malloc the memory for our buffer, if needed
    dataVertexBuffer = nil;
    struct Vertex* vertexBuffer = (struct Vertex*) malloc([self numberOfBytes]);
    
    // save our scale
    scaleOfVertexBuffer = scale;
    
    // now lets calculate the steps we need to adjust width
    CGFloat prevWidth =  [self widthOfPreviousElement:previousElement];
    CGFloat widthDiff = self.width - prevWidth;
    
    // next is the steps to adjust color
    GLfloat prevColor[4], myColor[4];
    GLfloat colorSteps[4];
    [[self colorOfPreviousElement:previousElement] getRGBAComponents:prevColor];
    [self.color getRGBAComponents:myColor];
    
    // calculate how much the RGBA will
    // need to change throughout the stroke
    colorSteps[0] = myColor[0] - prevColor[0];
    colorSteps[1] = myColor[1] - prevColor[1];
    colorSteps[2] = myColor[2] - prevColor[2];
    colorSteps[3] = myColor[3] - prevColor[3];
    
    CGFloat rotationDiff = self.rotation - previousElement.rotation;

    CGPoint* pointArr = (CGPoint*) malloc(sizeof(CGPoint)*6);

    // generate a single point vertex for each step
    // so that the stroke is essentially a series of dots
	for(int step = 0; step < numberOfVertices; step+=[self numberOfVerticesPerStep]) {
        // 0 <= t < 1
        CGFloat t = (CGFloat)step / (CGFloat)numberOfVertices;
        
        // current rotation
        CGFloat stepRotation = previousElement.rotation + rotationDiff * t;
        CGFloat stepWidth = (prevWidth + widthDiff * t) * scaleOfVertexBuffer;
        
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
            calcColor[0] = calcColor[0] * calcColor[3] / stepWidth;
            calcColor[1] = calcColor[1] * calcColor[3] / stepWidth;
            calcColor[2] = calcColor[2] * calcColor[3] / stepWidth;
        }
        
        [self arrayOfPositionsForPoint:point
                                                          andWidth:stepWidth
                                                       andRotation:stepRotation
                                                          outArray:pointArr];
        
        for(int innerStep = 0;innerStep < 6;innerStep++){
            CGPoint stepPoint = pointArr[innerStep];
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
    
    free(pointArr);
    
    dataVertexBuffer = [NSData dataWithBytesNoCopy:vertexBuffer length:[self numberOfBytes]];
    
    return (struct Vertex*) dataVertexBuffer.bytes;
}


-(BOOL) bind{
    if(!handle && dataVertexBuffer){
        int numberOfVertices = [self numberOfSteps] * [self numberOfVerticesPerStep];
        int mallocSize = numberOfVertices*sizeof(struct Vertex);
        glGenBuffers(1,&handle);
        glBindBuffer(GL_ARRAY_BUFFER,handle);
        glBufferData(GL_ARRAY_BUFFER, mallocSize, dataVertexBuffer.bytes, GL_STATIC_DRAW);
        glBindBuffer(GL_ARRAY_BUFFER,0);
    }
    if(handle){
        glBindBuffer(GL_ARRAY_BUFFER,handle);
    }
    return YES;
}

-(void) unbind{
    glBindBuffer(GL_ARRAY_BUFFER,0);
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


#pragma mark - PlistSaving

-(NSDictionary*) asDictionary{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:[super asDictionary]];
    [dict setObject:[NSNumber numberWithFloat:lineTo.x] forKey:@"lineTo.x"];
    [dict setObject:[NSNumber numberWithFloat:lineTo.y] forKey:@"lineTo.y"];
    [dict setObject:dataVertexBuffer forKey:@"vertexBuffer"];
    return [NSDictionary dictionaryWithDictionary:dict];
}

-(id) initFromDictionary:(NSDictionary*)dictionary{
    self = [super initFromDictionary:dictionary];
    if (self) {
        lineTo = CGPointMake([[dictionary objectForKey:@"lineTo.x"] floatValue], [[dictionary objectForKey:@"lineTo.y"] floatValue]);
        dataVertexBuffer = [dictionary objectForKey:@"vertexBuffer"];
        NSUInteger prime = 31;
        hashCache = 1;
        hashCache = prime * hashCache + startPoint.x;
        hashCache = prime * hashCache + startPoint.y;
        hashCache = prime * hashCache + lineTo.x;
        hashCache = prime * hashCache + lineTo.y;
    }
    return self;
}

#pragma mark - hashing and equality

-(NSUInteger) hash{
    return hashCache;
}

-(BOOL) isEqual:(id)object{
    return self == object || [self hash] == [object hash];
}


@end
