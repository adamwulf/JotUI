//
//  CurveToPathElement.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import "CurveToPathElement.h"
#import "UIColor+JotHelper.h"

@implementation CurveToPathElement

@synthesize curveTo;
@synthesize ctrl1;
@synthesize ctrl2;

-(id) initWithStart:(CGPoint)start
         andCurveTo:(CGPoint)_curveTo
        andControl1:(CGPoint)_ctrl1
        andControl2:(CGPoint)_ctrl2{
    if(self = [super initWithStart:start andLineTo:_curveTo]){
        curveTo = _curveTo;
        ctrl1 = _ctrl1;
        ctrl2 = _ctrl2;
    }
    return self;
}


+(id) elementWithStart:(CGPoint)start
            andCurveTo:(CGPoint)curveTo
           andControl1:(CGPoint)ctrl1
           andControl2:(CGPoint)ctrl2{
    return [[CurveToPathElement alloc] initWithStart:start andCurveTo:curveTo andControl1:ctrl1 andControl2:ctrl2];
}


///**
// * the length along the curve of this element.
// * since it's a curve, this will be longer than
// * the straight distance between start/end points
// */
//-(CGFloat) lengthOfElement{
//    if(length) return length;
//    
//    CGPoint bez[4];
//    bez[0] = startPoint;
//    bez[1] = ctrl1;
//    bez[2] = ctrl2;
//    bez[3] = curveTo;
//    
//    length = lengthOfBezier(bez, .1);
//    return length;
//}
//
///**
// * generate a vertex buffer array for all of the points
// * along this curve for the input scale.
// *
// * this method will cache the array for a single scale. if
// * a new scale is sent in later, then the cache will be rebuilt
// * for the new scale.
// */
//-(struct Vertex*) generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale{
//    // if we have a buffer generated and cached,
//    // then just return that
//    if(vertexBuffer && scaleOfVertexBuffer == scale){
//        return vertexBuffer;
//    }
//    // malloc the memory for our buffer, if needed
//    if(!vertexBuffer){
//        vertexBuffer = (struct Vertex*) malloc([self numberOfSteps]*sizeof(struct Vertex));
//    }
//    
//    // save our scale, we're only going to cache a vertex
//    // buffer for 1 scale at a time
//    scaleOfVertexBuffer = scale;
//    
//    // find out how many steps we can put inside this segment length
//	int numberOfSteps = [self numberOfSteps];
//    
//    // since kBrushStepSize doesn't exactly divide into our segment length,
//    // let's find a step size that /does/ exactly divide into our segment length
//    // that's very very close to our idealStepSize of kBrushStepSize
//    //
//    // this'll help make the segment join its neighboring segments
//    // without any artifacts of the start/end double drawing
//    CGFloat realStepSize = [self lengthOfElement] / numberOfSteps;
//    
//    //
//    // now setup what we need to calculate the changes in width
//    // along the stroke
//    CGFloat prevWidth = previousElement.width;
//    CGFloat widthDiff = self.width - prevWidth;
//    
//    
//    // setup a simple point array to represent our
//    // bezier. this'll be what we use to subdivide
//    // later on
//    CGPoint rightBez[4], leftBez[4];
//    CGPoint bez[4];
//    bez[0] = startPoint;
//    bez[1] = ctrl1;
//    bez[2] = ctrl2;
//    bez[3] = curveTo;
//    
//    // now find the differences in color between
//    // the previous stroke and this stroke
//    GLubyte prevColor[4], myColor[4];
//    short colorSteps[4];
//    [previousElement.color getRGBAComponents:prevColor];
//    [self.color getRGBAComponents:myColor];
//    colorSteps[0] = myColor[0] - prevColor[0];
//    colorSteps[1] = myColor[1] - prevColor[1];
//    colorSteps[2] = myColor[2] - prevColor[2];
//    colorSteps[3] = myColor[3] - prevColor[3];
//    
//    //
//    // calculate points along the curve that are realStepSize
//    // length along the curve. since this is fairly intensive for
//    // the CPU, we'll cache the results
//    for(int step = 0; step < numberOfSteps; step++) {
//        // 0 <= t < 1 representing where we are in the stroke element
//        CGFloat t = (CGFloat)step / (CGFloat)numberOfSteps;
//        
//        // calculate the point that is realStepSize distance
//        // along the curve * which step we're on
//        subdivideBezierAtLength(bez, leftBez, rightBez, realStepSize*step, .05);
//        CGPoint point = rightBez[0];
//        
//        // Convert locations from screen Points to GL points (screen pixels)
//        vertexBuffer[step].Position[0] = (GLfloat) point.x * scaleOfVertexBuffer;
//		vertexBuffer[step].Position[1] = (GLfloat) point.y * scaleOfVertexBuffer;
//        
//        // set colors to the array
//        if(!self.color){
//            // eraser
//            vertexBuffer[step].Color[0] = 0;
//            vertexBuffer[step].Color[1] = 0;
//            vertexBuffer[step].Color[2] = 0;
//            vertexBuffer[step].Color[3] = 255;
//        }else{
//            // normal brush
//            // interpolate between starting and ending color
//            vertexBuffer[step].Color[0] = prevColor[0] + colorSteps[0] * t;
//            vertexBuffer[step].Color[1] = prevColor[1] + colorSteps[1] * t;
//            vertexBuffer[step].Color[2] = prevColor[2] + colorSteps[2] * t;
//            vertexBuffer[step].Color[3] = prevColor[3] + colorSteps[3] * t;
//            
//            // premultiply alpha
//            vertexBuffer[step].Color[0] *= (vertexBuffer[step].Color[3] / 255.0);
//            vertexBuffer[step].Color[1] *= (vertexBuffer[step].Color[3] / 255.0);
//            vertexBuffer[step].Color[2] *= (vertexBuffer[step].Color[3] / 255.0);
//        }
//        
//        
//        // set vertex point size
//        CGFloat steppedWidth = prevWidth + widthDiff * t;
//        vertexBuffer[step].Size = steppedWidth*scaleOfVertexBuffer;
//    }
//    
//    return vertexBuffer;
//}

/**
 * helpful description when debugging
 */
-(NSString*)description{
    return [NSString stringWithFormat:@"[Line from: %f,%f  to: %f%f]", startPoint.x, startPoint.y, curveTo.x, curveTo.y];
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

@end
