//
//  CurveToPathElement.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import "CurveToPathElement.h"
#import "UIColor+JotHelper.h"
#import "AbstractBezierPathElement-Protected.h"
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@implementation CurveToPathElement{
    UIBezierPath* bezierCache;
    // cache the hash, since it's expenseive to calculate
    NSUInteger hashCache;
}

@synthesize curveTo;
@synthesize ctrl1;
@synthesize ctrl2;

-(id) initWithStart:(CGPoint)start
         andCurveTo:(CGPoint)_curveTo
        andControl1:(CGPoint)_ctrl1
        andControl2:(CGPoint)_ctrl2{
    if(self = [super initWithStart:start]){
        curveTo = _curveTo;
        ctrl1 = _ctrl1;
        ctrl2 = _ctrl2;

        NSUInteger prime = 31;
        hashCache = 1;
        hashCache = prime * hashCache + startPoint.x;
        hashCache = prime * hashCache + startPoint.y;
        hashCache = prime * hashCache + curveTo.x;
        hashCache = prime * hashCache + curveTo.y;
        hashCache = prime * hashCache + ctrl1.x;
        hashCache = prime * hashCache + ctrl1.y;
        hashCache = prime * hashCache + ctrl2.x;
        hashCache = prime * hashCache + ctrl2.y;
    }
    return self;
}


+(id) elementWithStart:(CGPoint)start
            andCurveTo:(CGPoint)curveTo
           andControl1:(CGPoint)ctrl1
           andControl2:(CGPoint)ctrl2{
    return [[CurveToPathElement alloc] initWithStart:start andCurveTo:curveTo andControl1:ctrl1 andControl2:ctrl2];
}


/**
 * the length along the curve of this element.
 * since it's a curve, this will be longer than
 * the straight distance between start/end points
 */
-(CGFloat) lengthOfElement{
    if(length) return length;
    
    CGPoint bez[4];
    bez[0] = startPoint;
    bez[1] = ctrl1;
    bez[2] = ctrl2;
    bez[3] = curveTo;
    
    length = lengthOfBezier(bez, .1);
    return length;
}

-(CGPoint) cgPointDiff:(CGPoint)point1 withPoint:(CGPoint)point2{
    return CGPointMake(point1.x - point2.x, point1.y - point2.y);
}

-(CGFloat) angleOfStart{
    return [self angleBetweenPoint:startPoint andPoint:ctrl1];
}

-(CGFloat) angleOfEnd{
    CGFloat possibleRet = [self angleBetweenPoint:ctrl2 andPoint:curveTo];
    CGFloat start = [self angleOfStart];
    if(ABS(start - possibleRet) > M_PI){
        CGFloat rotateRight = possibleRet + 2 * M_PI;
        CGFloat rotateLeft = possibleRet - 2 * M_PI;
        if(ABS(start - rotateRight) > M_PI){
            return rotateLeft;
        }else{
            return rotateRight;
        }
    }
    return possibleRet;
}

-(CGPoint) endPoint{
    return self.curveTo;
}
-(void) adjustStartBy:(CGPoint)adjustment{
    startPoint = CGPointMake(startPoint.x + adjustment.x, startPoint.y + adjustment.y);
    ctrl1 = CGPointMake(ctrl1.x + adjustment.x, ctrl1.y + adjustment.y);
}



-(CGRect) bounds{
    if(bezierCache){
        return CGRectInset(bezierCache.bounds, -width, -width);
    }
    bezierCache = [UIBezierPath bezierPath];
    [bezierCache moveToPoint:self.startPoint];
    [bezierCache addCurveToPoint:curveTo controlPoint1:ctrl1 controlPoint2:ctrl2];
    return [self bounds];
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
 */
-(struct Vertex*) generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale{
    // if we have a buffer generated and cached,
    // then just return that
    if(dataVertexBuffer && scaleOfVertexBuffer == scale){
        return (struct Vertex*) dataVertexBuffer.bytes;
    }
    // find out how many steps we can put inside this segment length
	int numberOfVertices = [self numberOfSteps] * [self numberOfVerticesPerStep];
    
    // malloc the memory for our buffer, if needed
    dataVertexBuffer = nil;
    struct Vertex* vertexBuffer = (struct Vertex*) malloc([self numberOfBytes]);
    
    // save our scale, we're only going to cache a vertex
    // buffer for 1 scale at a time
    scaleOfVertexBuffer = scale;
    
    // since kBrushStepSize doesn't exactly divide into our segment length,
    // let's find a step size that /does/ exactly divide into our segment length
    // that's very very close to our idealStepSize of kBrushStepSize
    //
    // this'll help make the segment join its neighboring segments
    // without any artifacts of the start/end double drawing
    CGFloat realStepSize = [self lengthOfElement] / numberOfVertices;
    
    //
    // now setup what we need to calculate the changes in width
    // along the stroke
    CGFloat prevWidth = previousElement.width;
    CGFloat widthDiff = self.width - prevWidth;
    
    
    // setup a simple point array to represent our
    // bezier. this'll be what we use to subdivide
    // later on
    CGPoint rightBez[4], leftBez[4];
    CGPoint bez[4];
    bez[0] = startPoint;
    bez[1] = ctrl1;
    bez[2] = ctrl2;
    bez[3] = curveTo;
    
    // now find the differences in color between
    // the previous stroke and this stroke
    GLfloat prevColor[4], myColor[4];
    GLfloat colorSteps[4];
    [previousElement.color getRGBAComponents:prevColor];
    [self.color getRGBAComponents:myColor];
    colorSteps[0] = myColor[0] - prevColor[0];
    colorSteps[1] = myColor[1] - prevColor[1];
    colorSteps[2] = myColor[2] - prevColor[2];
    colorSteps[3] = myColor[3] - prevColor[3];
    
    CGFloat rotationDiff = self.rotation - previousElement.rotation;
    
    CGPoint* pointArr = (CGPoint*) malloc(sizeof(CGPoint)*6);
    
    //
    // calculate points along the curve that are realStepSize
    // length along the curve. since this is fairly intensive for
    // the CPU, we'll cache the results
    for(int step = 0; step < numberOfVertices; step+=[self numberOfVerticesPerStep]) {
        // 0 <= t < 1 representing where we are in the stroke element
        CGFloat t = (CGFloat)step / (CGFloat)numberOfVertices;
        
        // current rotation
        CGFloat stepRotation = previousElement.rotation + rotationDiff * t;
        CGFloat stepWidth = (prevWidth + widthDiff * t) * scaleOfVertexBuffer;
        
        // calculate the point that is realStepSize distance
        // along the curve * which step we're on
        subdivideBezierAtLength(bez, leftBez, rightBez, realStepSize*step, .1);
        CGPoint point = rightBez[0];
        
        GLfloat calcColor[4];
        // set colors to the array
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
            
            calcColor[3] = calcColor[3] / (stepWidth/20);

            // premultiply alpha
            calcColor[0] = calcColor[0] * calcColor[3];
            calcColor[1] = calcColor[1] * calcColor[3];
            calcColor[2] = calcColor[2] * calcColor[3];
        }
        
        // Convert locations from screen Points to GL points (screen pixels)
        vertexBuffer[step].Position[0] = (GLfloat) point.x * scaleOfVertexBuffer;
		vertexBuffer[step].Position[1] = (GLfloat) point.y * scaleOfVertexBuffer;
        
        
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


/**
 * this method has become quite a bit more complex
 * than it was originally.
 *
 * when this method is called from a background thread,
 * it will generate and bind the VBO only. it won't create
 * a VAO
 *
 * when this method is called on the main thread, it will
 * create the VAO, and will also create the VBO to go with
 * it if needed. otherwise it'll bind the VBO from the
 * background thread into the VAO
 *
 * the [unbind] method will unbind either the VAO or VBO
 * depending on which was created/bound in this method+thread
 */
-(BOOL) bind{
    // we're only allowed to create vao
    // on the main thread.
    // if we need a vao, then create it
    if(!vbo && dataVertexBuffer){
        int numberOfVertices = [self numberOfSteps] * [self numberOfVerticesPerStep];
        int mallocSize = numberOfVertices*sizeof(struct Vertex);
        glGenBuffers(1,&vbo);
        glBindBuffer(GL_ARRAY_BUFFER,vbo);
        glBufferData(GL_ARRAY_BUFFER, mallocSize, dataVertexBuffer.bytes, GL_STATIC_DRAW);
    }else{
        glBindBuffer(GL_ARRAY_BUFFER,vbo);
    }
    glVertexPointer(2, GL_FLOAT, sizeof(struct Vertex), offsetof(struct Vertex, Position));
    glColorPointer(4, GL_FLOAT, sizeof(struct Vertex), offsetof(struct Vertex, Color));
    glTexCoordPointer(2, GL_SHORT, sizeof(struct Vertex), offsetof(struct Vertex, Texture));
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    return YES;
}

-(void) unbind{
    glBindBuffer(GL_ARRAY_BUFFER,0);
}


-(void) dealloc{
    if(vbo){
        glDeleteBuffers(1,&vbo);
    }
}

/**
 * helpful description when debugging
 */
-(NSString*)description{
    return [NSString stringWithFormat:@"[Curve from: %f,%f  to: %f%f]", startPoint.x, startPoint.y, curveTo.x, curveTo.y];
}


#pragma mark - Helper
/**
 * these bezier functions are licensed and used with permission from http://apptree.net/drawkit.htm
 */



/**
 * will divide a bezier curve into two curves at time t
 * 0 <= t <= 1.0
 *
 * these two curves will exactly match the former single curve
 */
static inline void subdivideBezierAtT(const CGPoint bez[4], CGPoint bez1[4], CGPoint bez2[4], CGFloat t){
    CGPoint q;
    CGFloat mt = 1 - t;
    
    bez1[0].x = bez[0].x;
    bez1[0].y = bez[0].y;
    bez2[3].x = bez[3].x;
    bez2[3].y = bez[3].y;
    
    q.x = mt * bez[1].x + t * bez[2].x;
    q.y = mt * bez[1].y + t * bez[2].y;
    bez1[1].x = mt * bez[0].x + t * bez[1].x;
    bez1[1].y = mt * bez[0].y + t * bez[1].y;
    bez2[2].x = mt * bez[2].x + t * bez[3].x;
    bez2[2].y = mt * bez[2].y + t * bez[3].y;
    
    bez1[2].x = mt * bez1[1].x + t * q.x;
    bez1[2].y = mt * bez1[1].y + t * q.y;
    bez2[1].x = mt * q.x + t * bez2[2].x;
    bez2[1].y = mt * q.y + t * bez2[2].y;
    
    bez1[3].x = bez2[0].x = mt * bez1[2].x + t * bez2[1].x;
    bez1[3].y = bez2[0].y = mt * bez1[2].y + t * bez2[1].y;
}

/**
 * divide the input curve at its halfway point
 */
static inline void subdivideBezier(const CGPoint bez[4], CGPoint bez1[4], CGPoint bez2[4]){
    subdivideBezierAtT(bez, bez1, bez2, .5);
}

/**
 * calculates the distance between two points
 */
static inline CGFloat distanceBetween(CGPoint a, CGPoint b){
    return hypotf( a.x - b.x, a.y - b.y );
}

/**
 * estimates the length along the curve of the
 * input bezier within the input acceptableError
 */
CGFloat lengthOfBezier(const  CGPoint bez[4], CGFloat acceptableError){
    CGFloat   polyLen = 0.0;
    CGFloat   chordLen = distanceBetween (bez[0], bez[3]);
    CGFloat   retLen, errLen;
    NSUInteger n;
    
    for (n = 0; n < 3; ++n)
        polyLen += distanceBetween (bez[n], bez[n + 1]);
    
    errLen = polyLen - chordLen;
    
    if (errLen > acceptableError) {
        CGPoint left[4], right[4];
        subdivideBezier (bez, left, right);
        retLen = (lengthOfBezier (left, acceptableError)
                  + lengthOfBezier (right, acceptableError));
    } else {
        retLen = 0.5 * (polyLen + chordLen);
    }
    
    return retLen;
}

/**
 * will split the input bezier curve at the input length
 * within a given margin of error
 *
 * the two curves will exactly match the original curve
 */
static CGFloat subdivideBezierAtLength (const CGPoint bez[4],
                                        CGPoint bez1[4],
                                        CGPoint bez2[4],
                                        CGFloat length,
                                        CGFloat acceptableError){
    CGFloat top = 1.0, bottom = 0.0;
    CGFloat t, prevT;
    
    prevT = t = 0.5;
    for (;;) {
        CGFloat len1;
        
        subdivideBezierAtT (bez, bez1, bez2, t);
        
        len1 = lengthOfBezier (bez1, 0.5 * acceptableError);
        
        if (fabs (length - len1) < acceptableError)
            return len1;
        
        if (length > len1) {
            bottom = t;
            t = 0.5 * (t + top);
        } else if (length < len1) {
            top = t;
            t = 0.5 * (bottom + t);
        }
        
        if (t == prevT)
            return len1;
        
        prevT = t;
    }
}



#pragma mark - PlistSaving

-(NSDictionary*) asDictionary{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:[super asDictionary]];
    [dict setObject:[NSNumber numberWithFloat:curveTo.x] forKey:@"curveTo.x"];
    [dict setObject:[NSNumber numberWithFloat:curveTo.y] forKey:@"curveTo.y"];
    [dict setObject:[NSNumber numberWithFloat:ctrl1.x] forKey:@"ctrl1.x"];
    [dict setObject:[NSNumber numberWithFloat:ctrl1.y] forKey:@"ctrl1.y"];
    [dict setObject:[NSNumber numberWithFloat:ctrl2.x] forKey:@"ctrl2.x"];
    [dict setObject:[NSNumber numberWithFloat:ctrl2.y] forKey:@"ctrl2.y"];
    [dict setObject:dataVertexBuffer forKey:@"vertexBuffer"];
    return [NSDictionary dictionaryWithDictionary:dict];
}

-(id) initFromDictionary:(NSDictionary*)dictionary{
    self = [super initFromDictionary:dictionary];
    if (self) {
        curveTo = CGPointMake([[dictionary objectForKey:@"curveTo.x"] floatValue], [[dictionary objectForKey:@"curveTo.y"] floatValue]);
        ctrl1 = CGPointMake([[dictionary objectForKey:@"ctrl1.x"] floatValue], [[dictionary objectForKey:@"ctrl1.y"] floatValue]);
        ctrl2 = CGPointMake([[dictionary objectForKey:@"ctrl2.x"] floatValue], [[dictionary objectForKey:@"ctrl2.y"] floatValue]);
        dataVertexBuffer = [dictionary objectForKey:@"vertexBuffer"];

        NSUInteger prime = 31;
        hashCache = 1;
        hashCache = prime * hashCache + startPoint.x;
        hashCache = prime * hashCache + startPoint.y;
        hashCache = prime * hashCache + curveTo.x;
        hashCache = prime * hashCache + curveTo.y;
        hashCache = prime * hashCache + ctrl1.x;
        hashCache = prime * hashCache + ctrl1.y;
        hashCache = prime * hashCache + ctrl2.x;
        hashCache = prime * hashCache + ctrl2.y;
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
