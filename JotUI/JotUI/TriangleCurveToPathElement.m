//
//  TriangleCurveToPathElement.m
//  JotUI
//
//  Created by Adam Wulf on 1/1/16.
//  Copyright © 2016 Adonit. All rights reserved.
//

#import "TriangleCurveToPathElement.h"
#import "AbstractBezierPathElement-Protected.h"
#import "UIColor+JotHelper.h"

#define kDivideStepBy 5
#define kAbsoluteMinWidth 3.0


@implementation TriangleCurveToPathElement


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
    return YES;
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

-(NSInteger) numberOfVerticesPerStep{
    return 1;
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

    vertexBufferShouldContainColor = YES;

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


    // find out how many steps we can put inside this segment length
    NSInteger numberOfVertices = [self numberOfVerticesGivenPreviousElement:previousElement];
    numberOfBytesOfVertexData = [self numberOfBytesGivenPreviousElement:previousElement];

    // malloc the memory for our buffer, if needed
    dataVertexBuffer = nil;

    // save our scale, we're only going to cache a vertex
    // buffer for 1 scale at a time
    scaleOfVertexBuffer = scale;

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
    //    DebugLog(@"realStepSize len: %f vert: %ld (prevextra: %f myextra: %f)", realLength, (long)numberOfVertices, previousElement.extraLengthWithoutDot, self.extraLengthWithoutDot);

    if(!numberOfVertices){
        //        DebugLog(@"nil buffer");
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
        //        DebugLog(@" dot at %f", distToDot);
        subdivideBezierAtLength2(bez, leftBez, rightBez, distToDot, .1, subBezierlengthCache);
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
    }

    dataVertexBuffer = [NSData dataWithBytesNoCopy:vertexBuffer length:numberOfBytesOfVertexData];

    return (struct ColorfulVertex*) dataVertexBuffer.bytes;
}



-(void) drawGivenPreviousElement:(AbstractBezierPathElement *)previousElement{
    if([self bind]){
        // VBO
        [JotGLContext runBlock:^(JotGLContext* context){
            if([self numberOfStepsGivenPreviousElement:previousElement]){
                [context drawPointCount:(int) ([self numberOfStepsGivenPreviousElement:previousElement] * [self numberOfVerticesPerStep])];
            }
        }];
        [self unbind];
    }
}


@end
