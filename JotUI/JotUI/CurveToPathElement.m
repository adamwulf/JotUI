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
#import "JotBufferManager.h"
#import "JotBufferVBO.h"
#import "MoveToPathElement.h"


#define kDivideStepBy 5
#define kAbsoluteMinWidth 5.0

@implementation CurveToPathElement{
    CGRect boundsCache;
    // cache the hash, since it's expenseive to calculate
    NSUInteger hashCache;
    // the VBO
    JotBufferVBO* vbo;
    // a boolean for if color information is encoded in the VBO
    BOOL vertexBufferShouldContainColor;
    // store the number of bytes of data that we've generated
    NSInteger numberOfBytesOfVertexData;
    // cached color components so that we don't recalculate
    // every time we bind
    BOOL hasCalculatedColorComponents;
    GLfloat colorComponents[4];
    
    CGFloat subBezierlengthCache[1000];
}

const CGPoint		JotCGNotFoundPoint = {-10000000.2,-999999.6};

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
        
        boundsCache.origin = JotCGNotFoundPoint;
    }
    return self;
}


+(id) elementWithStart:(CGPoint)start
            andCurveTo:(CGPoint)curveTo
           andControl1:(CGPoint)ctrl1
           andControl2:(CGPoint)ctrl2{
    return [[CurveToPathElement alloc] initWithStart:start andCurveTo:curveTo andControl1:ctrl1 andControl2:ctrl2];
}

+(id) elementWithStart:(CGPoint)start andLineTo:(CGPoint)point{
    return [CurveToPathElement elementWithStart:start andCurveTo:point andControl1:start andControl2:point];
}

-(int) fullByteSize{
    return vbo.fullByteSize;
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
    
    length = jotLengthOfBezier(bez, .1);
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
    if(boundsCache.origin.x == JotCGNotFoundPoint.x){
        CGFloat minX = MIN(MIN(MIN(startPoint.x, curveTo.x),ctrl1.x),ctrl2.x);
        CGFloat minY = MIN(MIN(MIN(startPoint.y, curveTo.y),ctrl1.y),ctrl2.y);
        CGFloat maxX = MAX(MAX(MAX(startPoint.x, curveTo.x),ctrl1.x),ctrl2.x);
        CGFloat maxY = MAX(MAX(MAX(startPoint.y, curveTo.y),ctrl1.y),ctrl2.y);
        boundsCache = CGRectMake(minX, minY, maxX - minX, maxY - minY);
        boundsCache = CGRectInset(boundsCache, -width, -width);
    }
    return boundsCache;
}


-(BOOL) shouldContainVertexColorDataGivenPreviousElement:(AbstractBezierPathElement*)previousElement{
    if(!previousElement){
        return NO;
    }
    if(!self.color){
        return NO;
    }
    
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
    
    BOOL shouldContainColor = YES;
    if(!self.color ||
       (colorSteps[0] == 0 &&
        colorSteps[1] == 0 &&
        colorSteps[2] == 0 &&
        colorSteps[3] == 0)){
           shouldContainColor = NO;
       }
    return shouldContainColor;
}

-(NSInteger) numberOfBytesGivenPreviousElement:(AbstractBezierPathElement*)previousElement{
    // find out how many steps we can put inside this segment length
    NSInteger numberOfVertices = [self numberOfVerticesGivenPreviousElement:previousElement];
    NSInteger numberOfBytes;
    if([self shouldContainVertexColorDataGivenPreviousElement:previousElement]){
        numberOfBytes = numberOfVertices*sizeof(struct ColorfulVertex);
    }else{
        numberOfBytes = numberOfVertices*sizeof(struct ColorlessVertex);
    }
    return numberOfBytes;
}


-(void) calculateAndCacheColorComponents{
    if(!hasCalculatedColorComponents){
        hasCalculatedColorComponents = YES;
        // save color components, because we'll use these
        // when we bind, since our colors won't be in the VBO
        if(self.color){
            [self.color getRGBAComponents:colorComponents];
            if(colorComponents[3] / (self.width / kDivideStepBy) < 0){
                NSLog(@"what?!!");
            }
            CGFloat stepWidth = self.width * scaleOfVertexBuffer;
            if(stepWidth < kAbsoluteMinWidth) stepWidth = kAbsoluteMinWidth;
            CGFloat alpha = colorComponents[3] / (stepWidth / kDivideStepBy);
            if(alpha > 1) alpha = 1;
            
            // set alpha first, because we'll premultiply immediately after
            colorComponents[3] = alpha;
            colorComponents[0] = colorComponents[0] * colorComponents[3];
            colorComponents[1] = colorComponents[1] * colorComponents[3];
            colorComponents[2] = colorComponents[2] * colorComponents[3];
        }else{
            colorComponents[0] = 0;
            colorComponents[1] = 0;
            colorComponents[2] = 0;
            colorComponents[3] = 1.0;
        }
    }
}

/**
 * generate a vertex buffer array for all of the points
 * along this curve for the input scale.
 *
 * this method will cache the array for a single scale. if
 * a new scale is sent in later, then the cache will be rebuilt
 * for the new scale.
 */
-(struct ColorfulVertex*) generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale{
    // if we have a buffer generated and cached,
    // then just return that
    if(dataVertexBuffer && scaleOfVertexBuffer == scale){
        return (struct ColorfulVertex*) dataVertexBuffer.bytes;
    }
    
    // now find the differences in color between
    // the previous stroke and this stroke
    GLfloat prevColor[4], myColor[4];
    prevColor[0] = prevColor[1] = prevColor[2] = prevColor[3] = 0;
    myColor[0] = myColor[1] = myColor[2] = myColor[3] = 0;
    GLfloat colorSteps[4];
    [previousElement.color getRGBAComponents:prevColor];
    [self.color getRGBAComponents:myColor];
    colorSteps[0] = myColor[0] - prevColor[0];
    colorSteps[1] = myColor[1] - prevColor[1];
    colorSteps[2] = myColor[2] - prevColor[2];
    colorSteps[3] = myColor[3] - prevColor[3];
    
    
    // check if we'll be saving the color information inside of our VBO
    // or if we'll set it during the bind instead
    vertexBufferShouldContainColor = [self shouldContainVertexColorDataGivenPreviousElement:previousElement];
    
    // find out how many steps we can put inside this segment length
    NSInteger numberOfVertices = [self numberOfVerticesGivenPreviousElement:previousElement];
    numberOfBytesOfVertexData = [self numberOfBytesGivenPreviousElement:previousElement];
    
    // malloc the memory for our buffer, if needed
    dataVertexBuffer = nil;
    
    // save our scale, we're only going to cache a vertex
    // buffer for 1 scale at a time
    scaleOfVertexBuffer = scale;
    
    if(!vertexBufferShouldContainColor){
        [self calculateAndCacheColorComponents];
    }
    
    // since kBrushStepSize doesn't exactly divide into our segment length,
    // let's find a step size that /does/ exactly divide into our segment length
    // that's very very close to our idealStepSize of kBrushStepSize
    //
    // this'll help make the segment join its neighboring segments
    // without any artifacts of the start/end double drawing
    CGFloat realLength = [self lengthOfElement];
    CGFloat realStepSize = kBrushStepSize; // numberOfVertices ? realLength / numberOfVertices : 0;
    CGFloat lengthPlusPrevExtra = realLength + previousElement.extraLengthWithoutDot;
    NSInteger divisionOfBrushStroke = floorf(lengthPlusPrevExtra / kBrushStepSize);
    // our extra length is whatever's leftover after chopping our length + previous extra
    // into kBrushStepSize sized segments.
    //
    // ie, if previous extra was .3, our length is 3.3, and our brush size is 2, then
    // our extra is:
    // divisionOfBrushStroke = floor(3.3 + .3) / 2 => floor(1.8) => 1
    // our extra = (3.6 - 1 * 2) => 1.6
    self.extraLengthWithoutDot = (lengthPlusPrevExtra - divisionOfBrushStroke * kBrushStepSize);
//    NSLog(@"realStepSize len: %f vert: %ld (prevextra: %f myextra: %f)", realLength, (long)numberOfVertices, previousElement.extraLengthWithoutDot, self.extraLengthWithoutDot);
    
    if(!numberOfVertices){
//        NSLog(@"nil buffer");
        dataVertexBuffer = [NSData data];
        return nil;
    }
    
    void* vertexBuffer = malloc(numberOfBytesOfVertexData);
    if(!vertexBuffer){
        @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't malloc" userInfo:nil];
    }
    

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
    
    // track if we're the first element in a stroke. we know this
    // if we follow a moveTo. This way we know if we should
    // include the first dot in the stroke.
    BOOL isFirstElementInStroke = [previousElement isKindOfClass:[MoveToPathElement class]];
    
    //
    // calculate points along the curve that are realStepSize
    // length along the curve. since this is fairly intensive for
    // the CPU, we'll cache the results
    for(int step = 0; step < numberOfVertices; step+=[self numberOfVerticesPerStep]) {
        // 0 <= t < 1 representing where we are in the stroke element
        CGFloat t = (CGFloat)step / (CGFloat)numberOfVertices;
        
        // current width
        CGFloat stepWidth = (prevWidth + widthDiff * t) * scaleOfVertexBuffer;
        // ensure min width for dots
        if(stepWidth < kAbsoluteMinWidth) stepWidth = kAbsoluteMinWidth;
        
        // calculate the point that is realStepSize distance
        // along the curve * which step we're on
        //
        // if we're the first non-move to element on a line, then we should also
        // have the dot at the beginning of our element. otherwise, we should only
        // add an element after kBrushStepSize (including whatever distance was
        // leftover)
        CGFloat distToDot = realStepSize*step + (isFirstElementInStroke ? 0 : kBrushStepSize - previousElement.extraLengthWithoutDot);
//        NSLog(@" dot at %f", distToDot);
        subdivideBezierAtLength(bez, leftBez, rightBez, distToDot, .1, subBezierlengthCache);
        CGPoint point = rightBez[0];
        
        GLfloat calcColor[4];
        // set colors to the array
        if(!self.color){
            // eraser
            calcColor[0] = 0;
            calcColor[1] = 0;
            calcColor[2] = 0;
            calcColor[3] = 1.0;
        }else{
            // normal brush
            // interpolate between starting and ending color
            calcColor[0] = prevColor[0] + colorSteps[0] * t;
            calcColor[1] = prevColor[1] + colorSteps[1] * t;
            calcColor[2] = prevColor[2] + colorSteps[2] * t;
            calcColor[3] = prevColor[3] + colorSteps[3] * t;
            
            calcColor[3] = calcColor[3] / (stepWidth / kDivideStepBy);
            if(calcColor[3] > 1){
                calcColor[3] = 1;
            }

            // premultiply alpha
            calcColor[0] = calcColor[0] * calcColor[3];
            calcColor[1] = calcColor[1] * calcColor[3];
            calcColor[2] = calcColor[2] * calcColor[3];
        }
        // Convert locations from screen Points to GL points (screen pixels)
        if(vertexBufferShouldContainColor){
            struct ColorfulVertex* coloredVertexBuffer = (struct ColorfulVertex*)vertexBuffer;
            // set colors to the array
            coloredVertexBuffer[step].Position[0] = (GLfloat) point.x * scaleOfVertexBuffer;
            coloredVertexBuffer[step].Position[1] = (GLfloat) point.y * scaleOfVertexBuffer;
            coloredVertexBuffer[step].Color[0] = calcColor[0];
            coloredVertexBuffer[step].Color[1] = calcColor[1];
            coloredVertexBuffer[step].Color[2] = calcColor[2];
            coloredVertexBuffer[step].Color[3] = calcColor[3];
            coloredVertexBuffer[step].Size = stepWidth;
            [self validateVertexData:coloredVertexBuffer[step]];
        }else{
            struct ColorlessVertex* colorlessVertexBuffer = (struct ColorlessVertex*)vertexBuffer;
            // set colors to the array
            colorlessVertexBuffer[step].Position[0] = (GLfloat) point.x * scaleOfVertexBuffer;
            colorlessVertexBuffer[step].Position[1] = (GLfloat) point.y * scaleOfVertexBuffer;
            colorlessVertexBuffer[step].Size = stepWidth;
        }
    }
    
    dataVertexBuffer = [NSData dataWithBytesNoCopy:vertexBuffer length:numberOfBytesOfVertexData];
    
    return (struct ColorfulVertex*) dataVertexBuffer.bytes;
}

-(void) validateVertexData:(struct ColorfulVertex)vertex{
    if(vertex.Color[0] < 0 || vertex.Color[0] > 1){
        NSLog(@"what?!1");
    }
    if(vertex.Color[1] < 0 || vertex.Color[1] > 1){
        NSLog(@"what?!2");
    }
    if(vertex.Color[2] < 0 || vertex.Color[2] > 1){
        NSLog(@"what?!3");
    }
    if(vertex.Color[3] < 0 || vertex.Color[3] > 1){
        NSLog(@"what?!4");
    }
    if(vertex.Size < 1 || vertex.Size > 360){
        NSLog(@"what?!5");
    }
    if(vertex.Position[0] < -50 || vertex.Position[0] > 1600){
        NSLog(@"what?!6");
    }
    if(vertex.Position[1] < -50 || vertex.Position[1] > 2080){
        NSLog(@"what?!7");
    }
}

-(void) loadDataIntoVBOIfNeeded{
    // we're only allowed to create vbo
    // on the main thread.
    // if we need a vbo, then create it
    if(!vbo && dataVertexBuffer.length){
        if(!self.bufferManager){
            NSLog(@"what");
        }
        vbo = [self.bufferManager bufferWithData:dataVertexBuffer];
    }
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
    if(!dataVertexBuffer.length){
//        NSLog(@"refusing to bind, we have no data");
        return NO;
    }
    // we're only allowed to create vbo
    // on the main thread.
    // if we need a vbo, then create it
    [self loadDataIntoVBOIfNeeded];
    if(vertexBufferShouldContainColor){
        [vbo bind];
    }else{
        // by this point, we've cached our components into
        // colorComponents, even if self.color is nil we've
        // set it appropriately
        [vbo bindForColor:colorComponents];
    }
/**
 * debugging code to validate vertex data when binding
 *
    if(vertexBufferShouldContainColor && dataVertexBuffer){
        struct ColorfulVertex* data = (struct ColorfulVertex*) [dataVertexBuffer bytes];
        for(int i =0 ;i<50 && i<[self numberOfSteps];i++){
            struct ColorfulVertex vert = data[i];
            if(vert.Position[0] < 0 ||
               vert.Position[1] < 0 ||
               vert.Size < 1){
                NSLog(@"what");
            }
        }
    }else if(dataVertexBuffer){
        struct ColorlessVertex* data = (struct ColorlessVertex*) [dataVertexBuffer bytes];
        for(int i =0 ;i<50 && i<[self numberOfSteps];i++){
            struct ColorlessVertex vert = data[i];
            if(vert.Position[0] < 0 ||
               vert.Position[1] < 0 ||
               vert.Size < 1){
                NSLog(@"what");
            }
        }
    }
*/
    return YES;
}

-(void) unbind{
    if(vbo.fullByteSize){
        [vbo unbind];
    }
}


-(void) dealloc{
    if(vbo){
        [self.bufferManager recycleBuffer:vbo];
        vbo = nil;
    }
}

/**
 * helpful description when debugging
 */
-(NSString*)description{
    if(CGPointEqualToPoint(startPoint, ctrl1) && CGPointEqualToPoint(curveTo, ctrl2)){
        return [NSString stringWithFormat:@"[Line from: %f,%f  to: %f,%f]", startPoint.x, startPoint.y, curveTo.x, curveTo.y];
    }else{
        return [NSString stringWithFormat:@"[Curve from: %f,%f  to: %f,%f]", startPoint.x, startPoint.y, curveTo.x, curveTo.y];
    }
}


#pragma mark - Helper
/**
 * these bezier functions are licensed and used with permission from http://apptree.net/drawkit.htm
 */

-(void) setColor:(UIColor *)_color{
    color = _color;
}

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
CGFloat jotLengthOfBezier(const  CGPoint bez[4], CGFloat acceptableError){
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
        retLen = (jotLengthOfBezier (left, acceptableError)
                  + jotLengthOfBezier (right, acceptableError));
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
                                        CGFloat acceptableError,
                                        CGFloat* subBezierlengthCache){
    CGFloat top = 1.0, bottom = 0.0;
    CGFloat t, prevT;
    
    prevT = t = 0.5;
    for (;;) {
        CGFloat len1;
        
        subdivideBezierAtT (bez, bez1, bez2, t);

        int lengthCacheIndex = (int)floorf(t*1000);
        len1 = subBezierlengthCache[lengthCacheIndex];
        if(!len1){
            len1 = jotLengthOfBezier (bez1, 0.5 * acceptableError);
            subBezierlengthCache[lengthCacheIndex] = len1;
        }
        
        if (fabs (length - len1) < acceptableError){
            return len1;
        }
        
        if (length > len1) {
            bottom = t;
            t = 0.5 * (t + top);
        } else if (length < len1) {
            top = t;
            t = 0.5 * (bottom + t);
        }
        
        if (t == prevT){
            subBezierlengthCache[lengthCacheIndex] = len1;
            return len1;
        }
        
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
    [dict setObject:[NSNumber numberWithBool:vertexBufferShouldContainColor] forKey:@"vertexBufferShouldContainColor"];
    [dict setObject:dataVertexBuffer forKey:@"vertexBuffer"];
    [dict setObject:[NSNumber numberWithFloat:numberOfBytesOfVertexData] forKey:@"numberOfBytesOfVertexData"];
    return [NSDictionary dictionaryWithDictionary:dict];
}

-(id) initFromDictionary:(NSDictionary*)dictionary{
    self = [super initFromDictionary:dictionary];
    if (self) {
        boundsCache.origin = JotCGNotFoundPoint;
        curveTo = CGPointMake([[dictionary objectForKey:@"curveTo.x"] floatValue], [[dictionary objectForKey:@"curveTo.y"] floatValue]);
        ctrl1 = CGPointMake([[dictionary objectForKey:@"ctrl1.x"] floatValue], [[dictionary objectForKey:@"ctrl1.y"] floatValue]);
        ctrl2 = CGPointMake([[dictionary objectForKey:@"ctrl2.x"] floatValue], [[dictionary objectForKey:@"ctrl2.y"] floatValue]);
        dataVertexBuffer = [dictionary objectForKey:@"vertexBuffer"];
        vertexBufferShouldContainColor = [[dictionary objectForKey:@"vertexBufferShouldContainColor"] boolValue];
        numberOfBytesOfVertexData = [[dictionary objectForKey:@"numberOfBytesOfVertexData"] integerValue];
        
        if(!vertexBufferShouldContainColor){
            [self calculateAndCacheColorComponents];
        }
        
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

/**
 * if we ever change how we render segments, then the data that's stored in our
 * dataVertexBuffer will contain "bad" data, since it would have been generated
 * for an older/different render method.
 *
 * we need to validate that we have the exact number of bytes of data to render
 * that we think we do
 */
-(void) validateDataGivenPreviousElement:(AbstractBezierPathElement*)previousElement{
    // noop, we don't have data
    NSInteger numberOfBytesThatWeNeed = [self numberOfBytesGivenPreviousElement:previousElement];
    if(numberOfBytesThatWeNeed != numberOfBytesOfVertexData){
        // force reload
        scaleOfVertexBuffer = 0;
        dataVertexBuffer = nil;
        numberOfBytesOfVertexData = 0;
    }else{
        // noop, we're good
    }
}

-(UIBezierPath*) bezierPathSegment{
    UIBezierPath* strokePath = [UIBezierPath bezierPath];
    [strokePath moveToPoint:self.startPoint];
    [strokePath addCurveToPoint:self.endPoint controlPoint1:self.ctrl1 controlPoint2:self.ctrl2];
    return strokePath;
}


#pragma mark - hashing and equality

-(NSUInteger) hash{
    return hashCache;
}

-(BOOL) isEqual:(id)object{
    return self == object || [self hash] == [object hash];
}

@end
