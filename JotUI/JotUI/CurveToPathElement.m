//
//  CurveToPathElement.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import "CurveToPathElement.h"
#import "UIColor+JotHelper.h"
#import "AbstractBezierPathElement-Protected.h"
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import "JotBufferManager.h"
#import "JotBufferVBO.h"
#import "MoveToPathElement.h"
#import "JotGLContext.h"
#import "JotTrashManager.h"
#import "JotGLPointProgram.h"
#import "JotGLColorlessPointProgram.h"
#import "JotGLColoredPointProgram.h"

#define kDivideStepBy 1.5
#define kAbsoluteMinWidth 0.5


@implementation CurveToPathElement {
    CGRect _boundsCache;
    // cache the hash, since it's expenseive to calculate
    NSUInteger _hashCache;
    // the VBO
    JotBufferVBO* _vbo;
    // a boolean for if color information is encoded in the VBO
    BOOL _vertexBufferShouldContainColor;
    // store the number of bytes of data that we've generated
    NSInteger _numberOfBytesOfVertexData;
    // cached color components so that we don't recalculate
    // every time we bind
    BOOL _hasCalculatedColorComponents;
    GLfloat _colorComponents[4];

    CGFloat _subBezierlengthCache[1000];

    NSLock* _lock;
}

const CGPoint JotCGNotFoundPoint = {-10000000.2, -999999.6};

- (id)initWithStart:(CGPoint)start
         andCurveTo:(CGPoint)curveTo
        andControl1:(CGPoint)ctrl1
        andControl2:(CGPoint)ctrl2 {
    if (self = [super initWithStart:start]) {
        _curveTo = curveTo;
        _ctrl1 = ctrl1;
        _ctrl2 = ctrl2;

        NSUInteger prime = 31;
        _hashCache = 1;
        _hashCache = prime * _hashCache + _startPoint.x;
        _hashCache = prime * _hashCache + _startPoint.y;
        _hashCache = prime * _hashCache + _curveTo.x;
        _hashCache = prime * _hashCache + _curveTo.y;
        _hashCache = prime * _hashCache + _ctrl1.x;
        _hashCache = prime * _hashCache + _ctrl1.y;
        _hashCache = prime * _hashCache + _ctrl2.x;
        _hashCache = prime * _hashCache + _ctrl2.y;

        _boundsCache.origin = JotCGNotFoundPoint;

        _lock = [[NSLock alloc] init];
    }
    return self;
}


+ (id)elementWithStart:(CGPoint)start
            andCurveTo:(CGPoint)curveTo
           andControl1:(CGPoint)ctrl1
           andControl2:(CGPoint)ctrl2 {
    return [[CurveToPathElement alloc] initWithStart:start andCurveTo:curveTo andControl1:ctrl1 andControl2:ctrl2];
}

+ (id)elementWithStart:(CGPoint)start andLineTo:(CGPoint)point {
    return [CurveToPathElement elementWithStart:start andCurveTo:point andControl1:start andControl2:point];
}

- (int)fullByteSize {
    return _vbo.fullByteSize;
}


/**
 * the length along the curve of this element.
 * since it's a curve, this will be longer than
 * the straight distance between start/end points
 */
- (CGFloat)lengthOfElement {
    if (_length)
        return _length;

    CGPoint bez[4];
    bez[0] = _startPoint;
    bez[1] = _ctrl1;
    bez[2] = _ctrl2;
    bez[3] = _curveTo;

    _length = jotLengthOfBezier(bez, .1);
    return _length;
}

- (CGPoint)cgPointDiff:(CGPoint)point1 withPoint:(CGPoint)point2 {
    return CGPointMake(point1.x - point2.x, point1.y - point2.y);
}

- (CGFloat)angleOfStart {
    return [self angleBetweenPoint:_startPoint andPoint:_ctrl1];
}

- (CGFloat)angleOfEnd {
    CGFloat possibleRet = [self angleBetweenPoint:_ctrl2 andPoint:_curveTo];
    CGFloat start = [self angleOfStart];
    if (ABS(start - possibleRet) > M_PI) {
        CGFloat rotateRight = possibleRet + 2 * M_PI;
        CGFloat rotateLeft = possibleRet - 2 * M_PI;
        if (ABS(start - rotateRight) > M_PI) {
            return rotateLeft;
        } else {
            return rotateRight;
        }
    }
    return possibleRet;
}

- (CGPoint)endPoint {
    return self.curveTo;
}
- (void)adjustStartBy:(CGPoint)adjustment {
    _startPoint = CGPointMake(_startPoint.x + adjustment.x, _startPoint.y + adjustment.y);
    _ctrl1 = CGPointMake(_ctrl1.x + adjustment.x, _ctrl1.y + adjustment.y);
}


- (CGRect)bounds {
    if (_boundsCache.origin.x == JotCGNotFoundPoint.x) {
        CGFloat minX = MIN(MIN(MIN(_startPoint.x, _curveTo.x), _ctrl1.x), _ctrl2.x);
        CGFloat minY = MIN(MIN(MIN(_startPoint.y, _curveTo.y), _ctrl1.y), _ctrl2.y);
        CGFloat maxX = MAX(MAX(MAX(_startPoint.x, _curveTo.x), _ctrl1.x), _ctrl2.x);
        CGFloat maxY = MAX(MAX(MAX(_startPoint.y, _curveTo.y), _ctrl1.y), _ctrl2.y);
        _boundsCache = CGRectMake(minX, minY, maxX - minX, maxY - minY);
        _boundsCache = CGRectInset(_boundsCache, -_width, -_width);
    }
    return _boundsCache;
}


- (BOOL)shouldContainVertexColorData {
    if (![self previousColor]) {
        return NO;
    }
    if (!self.color) {
        return NO;
    }

    // now find the differences in color between
    // the previous stroke and this stroke
    GLfloat prevColor[4], myColor[4];
    GLfloat colorSteps[4];
    [[self previousColor] getRGBAComponents:prevColor];
    [self.color getRGBAComponents:myColor];
    colorSteps[0] = myColor[0] - prevColor[0];
    colorSteps[1] = myColor[1] - prevColor[1];
    colorSteps[2] = myColor[2] - prevColor[2];
    colorSteps[3] = myColor[3] - prevColor[3];

    BOOL shouldContainColor = YES;
    if (!self.color ||
        (colorSteps[0] == 0 &&
         colorSteps[1] == 0 &&
         colorSteps[2] == 0 &&
         colorSteps[3] == 0)) {
        shouldContainColor = NO;
    }
    return shouldContainColor;
}

- (NSInteger)numberOfBytes {
    // find out how many steps we can put inside this segment length
    NSInteger numberOfVertices = [self numberOfVertices];
    NSInteger numberOfBytes;
    if ([self shouldContainVertexColorData]) {
        numberOfBytes = numberOfVertices * sizeof(struct ColorfulVertex);
    } else {
        numberOfBytes = numberOfVertices * sizeof(struct ColorlessVertex);
    }
    return numberOfBytes;
}


- (void)calculateAndCacheColorComponents {
    if (!_hasCalculatedColorComponents) {
        _hasCalculatedColorComponents = YES;
        // save color components, because we'll use these
        // when we bind, since our colors won't be in the VBO
        if (self.color) {
            [self.color getRGBAComponents:_colorComponents];

            NSAssert(_colorComponents[3] / (self.width / kDivideStepBy) > 0, @"color can't be negative");

            CGFloat stepWidth = self.width * _scaleOfVertexBuffer;
            if (stepWidth < kAbsoluteMinWidth)
                stepWidth = kAbsoluteMinWidth;
            CGFloat alpha = _colorComponents[3] / kDivideStepBy;
            if (alpha > 1)
                alpha = 1;

            // set alpha first, because we'll premultiply immediately after
            _colorComponents[3] = alpha;
            _colorComponents[0] = _colorComponents[0] * _colorComponents[3];
            _colorComponents[1] = _colorComponents[1] * _colorComponents[3];
            _colorComponents[2] = _colorComponents[2] * _colorComponents[3];
        } else {
            _colorComponents[0] = 0;
            _colorComponents[1] = 0;
            _colorComponents[2] = 0;
            _colorComponents[3] = 1.0;
        }
    }
}

/**
 * the ideal number of steps we should take along
 * this line to render it with vertex points
 */
- (NSInteger)numberOfSteps {
    NSInteger ret = MAX(floorf(([self lengthOfElement] + [self previousExtraLengthWithoutDot]) / [self stepWidth]), 0);
    // if we are beginning the stroke, then we have 1 more
    // dot to begin the stroke. otherwise we skip the first dot
    // and pick up after kBrushStepSize
    if ([self followsMoveTo]) {
        ret += 1;
    }
    return ret;
}

/**
 * generate a vertex buffer array for all of the points
 * along this curve for the input scale.
 *
 * this method will cache the array for a single scale. if
 * a new scale is sent in later, then the cache will be rebuilt
 * for the new scale.
 */
- (struct ColorfulVertex*)generatedVertexArrayForScale:(CGFloat)scale {
    // if we have a buffer generated and cached,
    // then just return that
    if (_dataVertexBuffer && _scaleOfVertexBuffer == scale) {
        return (struct ColorfulVertex*)_dataVertexBuffer.bytes;
    }

    // now find the differences in color between
    // the previous stroke and this stroke
    GLfloat prevColor[4], myColor[4];
    prevColor[0] = prevColor[1] = prevColor[2] = prevColor[3] = 0;
    myColor[0] = myColor[1] = myColor[2] = myColor[3] = 0;
    GLfloat colorSteps[4];
    [[self previousColor] getRGBAComponents:prevColor];
    [self.color getRGBAComponents:myColor];
    colorSteps[0] = myColor[0] - prevColor[0];
    colorSteps[1] = myColor[1] - prevColor[1];
    colorSteps[2] = myColor[2] - prevColor[2];
    colorSteps[3] = myColor[3] - prevColor[3];


    // check if we'll be saving the color information inside of our VBO
    // or if we'll set it during the bind instead
    _vertexBufferShouldContainColor = [self shouldContainVertexColorData];

    // find out how many steps we can put inside this segment length
    NSInteger numberOfVertices = [self numberOfVertices];
    _numberOfBytesOfVertexData = [self numberOfBytes];

    if (_numberOfBytesOfVertexData < 0) {
        @throw [NSException exceptionWithName:@"MemoryException" reason:@"numberOfBytesOfVertexData must be larger than 0" userInfo:nil];
    }

    // malloc the memory for our buffer, if needed
    _dataVertexBuffer = nil;

    // save our scale, we're only going to cache a vertex
    // buffer for 1 scale at a time
    _scaleOfVertexBuffer = scale;

    if (!_vertexBufferShouldContainColor) {
        [self calculateAndCacheColorComponents];
    }

    // since kBrushStepSize doesn't exactly divide into our segment length,
    // let's find a step size that /does/ exactly divide into our segment length
    // that's very very close to our idealStepSize of kBrushStepSize
    //
    // this'll help make the segment join its neighboring segments
    // without any artifacts of the start/end double drawing
    CGFloat realLength = [self lengthOfElement];
    CGFloat realStepSize = [self stepWidth]; // numberOfVertices ? realLength / numberOfVertices : 0;
    CGFloat lengthPlusPrevExtra = realLength + [self previousExtraLengthWithoutDot];
    NSInteger divisionOfBrushStroke = floorf(lengthPlusPrevExtra / realStepSize);
    // our extra length is whatever's leftover after chopping our length + previous extra
    // into kBrushStepSize sized segments.
    //
    // ie, if previous extra was .3, our length is 3.3, and our brush size is 2, then
    // our extra is:
    // divisionOfBrushStroke = floor(3.3 + .3) / 2 => floor(1.8) => 1
    // our extra = (3.6 - 1 * 2) => 1.6
    self.extraLengthWithoutDot = (lengthPlusPrevExtra - divisionOfBrushStroke * realStepSize);

    if (!numberOfVertices) {
        _dataVertexBuffer = [NSData data];
        return nil;
    }

    void* vertexBuffer = malloc(_numberOfBytesOfVertexData);
    if (!vertexBuffer) {
        @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't malloc" userInfo:nil];
    }

    //
    // now setup what we need to calculate the changes in width
    // along the stroke
    CGFloat prevWidth = [self previousWidth];
    CGFloat widthDiff = self.width - prevWidth;


    // setup a simple point array to represent our
    // bezier. this'll be what we use to subdivide
    // later on
    CGPoint rightBez[4], leftBez[4];
    CGPoint bez[4];
    bez[0] = _startPoint;
    bez[1] = _ctrl1;
    bez[2] = _ctrl2;
    bez[3] = _curveTo;

    // track if we're the first element in a stroke. we know this
    // if we follow a moveTo. This way we know if we should
    // include the first dot in the stroke.
    BOOL isFirstElementInStroke = [self followsMoveTo];

    //
    // calculate points along the curve that are realStepSize
    // length along the curve. since this is fairly intensive for
    // the CPU, we'll cache the results
    for (int step = 0; step < numberOfVertices; step += [self numberOfVerticesPerStep]) {
        // 0 <= t < 1 representing where we are in the stroke element
        CGFloat t = (CGFloat)step / (CGFloat)numberOfVertices;

        // current width
        CGFloat stepWidth = (prevWidth + widthDiff * t) * _scaleOfVertexBuffer;
        // ensure min width for dots
        if (stepWidth < kAbsoluteMinWidth)
            stepWidth = kAbsoluteMinWidth;

        // calculate the point that is realStepSize distance
        // along the curve * which step we're on
        //
        // if we're the first non-move to element on a line, then we should also
        // have the dot at the beginning of our element. otherwise, we should only
        // add an element after kBrushStepSize (including whatever distance was
        // leftover)
        CGFloat distToDot = realStepSize * step + (isFirstElementInStroke ? 0 : realStepSize - [self previousExtraLengthWithoutDot]);
        subdivideBezierAtLength(bez, leftBez, rightBez, distToDot, .1, _subBezierlengthCache);
        CGPoint point = rightBez[0];

        GLfloat calcColor[4];
        // set colors to the array
        if (!self.color) {
            // eraser
            calcColor[0] = 0;
            calcColor[1] = 0;
            calcColor[2] = 0;
            calcColor[3] = 1.0;
        } else {
            // normal brush
            // interpolate between starting and ending color
            calcColor[0] = prevColor[0] + colorSteps[0] * t;
            calcColor[1] = prevColor[1] + colorSteps[1] * t;
            calcColor[2] = prevColor[2] + colorSteps[2] * t;
            calcColor[3] = prevColor[3] + colorSteps[3] * t;

            calcColor[3] = calcColor[3] / kDivideStepBy;
            if (calcColor[3] > 1) {
                calcColor[3] = 1;
            }

            // premultiply alpha
            calcColor[0] = calcColor[0] * calcColor[3];
            calcColor[1] = calcColor[1] * calcColor[3];
            calcColor[2] = calcColor[2] * calcColor[3];
        }
        // Convert locations from screen Points to GL points (screen pixels)
        if (_vertexBufferShouldContainColor) {
            struct ColorfulVertex* coloredVertexBuffer = (struct ColorfulVertex*)vertexBuffer;
            // set colors to the array
            coloredVertexBuffer[step].Position[0] = (GLfloat)point.x * _scaleOfVertexBuffer;
            coloredVertexBuffer[step].Position[1] = (GLfloat)point.y * _scaleOfVertexBuffer;
            coloredVertexBuffer[step].Color[0] = calcColor[0];
            coloredVertexBuffer[step].Color[1] = calcColor[1];
            coloredVertexBuffer[step].Color[2] = calcColor[2];
            coloredVertexBuffer[step].Color[3] = calcColor[3];
            coloredVertexBuffer[step].Size = stepWidth;
            [self validateVertexData:coloredVertexBuffer[step]];
        } else {
            struct ColorlessVertex* colorlessVertexBuffer = (struct ColorlessVertex*)vertexBuffer;
            // set colors to the array
            colorlessVertexBuffer[step].Position[0] = (GLfloat)point.x * _scaleOfVertexBuffer;
            colorlessVertexBuffer[step].Position[1] = (GLfloat)point.y * _scaleOfVertexBuffer;
            colorlessVertexBuffer[step].Size = stepWidth;
        }
    }

    _dataVertexBuffer = [NSData dataWithBytesNoCopy:vertexBuffer length:_numberOfBytesOfVertexData];

    return (struct ColorfulVertex*)_dataVertexBuffer.bytes;
}

static CGFloat screenWidth;
static CGFloat screenHeight;

- (void)validateVertexData:(struct ColorfulVertex)vertex {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat scale = [[UIScreen mainScreen] scale];
        screenWidth = CGRectGetWidth([[[UIScreen mainScreen] fixedCoordinateSpace] bounds]) * scale + 50;
        screenHeight = CGRectGetHeight([[[UIScreen mainScreen] fixedCoordinateSpace] bounds]) * scale + 50;
    });


    NSAssert(!(vertex.Size < 1 || vertex.Size > 360), @"valid vertex size");
}

- (void)loadDataIntoVBOIfNeeded {
    // we're only allowed to create vbo
    // on the main thread.
    // if we need a vbo, then create it
    if (!_vbo && _dataVertexBuffer.length) {
        NSAssert(self.bufferManager, @"Buffer manager exists");
        _vbo = [self.bufferManager bufferWithData:_dataVertexBuffer];
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
- (BOOL)bind {
    if (![_lock tryLock]) {
        [_lock lock];
    }
    if (!_dataVertexBuffer.length) {
        // refusing to bind, we have no data
        [_lock unlock];
        return NO;
    }
    [JotGLContext runBlock:^(JotGLContext* context) {
        // we're only allowed to create vbo
        // on the main thread.
        // if we need a vbo, then create it
        JotGLPointProgram* program = (JotGLPointProgram*)[self glProgramForContext:context];
        program.rotation = self.rotation;
        [program use];

        [self loadDataIntoVBOIfNeeded];
        if (_vertexBufferShouldContainColor) {
            [_vbo bind];
        } else {
            // by this point, we've cached our components into
            // colorComponents, even if self.color is nil we've
            // set it appropriately
            [_vbo bindForColor:_colorComponents];
        }
    }];
    return YES;
}

- (void)unbind {
    [JotGLContext runBlock:^(JotGLContext* context) {
        if (_dataVertexBuffer.length) {
            [_vbo unbind];
        }
        [_lock unlock];
    }];
}

- (JotGLProgram*)glProgramForContext:(JotGLContext*)context {
    if (_vertexBufferShouldContainColor) {
        return [context coloredPointProgram];
    } else {
        JotGLColorlessPointProgram* clpp = [context colorlessPointProgram];
        clpp.colorRed = _colorComponents[0];
        clpp.colorGreen = _colorComponents[1];
        clpp.colorBlue = _colorComponents[2];
        clpp.colorAlpha = _colorComponents[3];

        return [context colorlessPointProgram];
    }
}


- (void)dealloc {
    if (_vbo) {
        [self.bufferManager recycleBuffer:_vbo];
        _vbo = nil;
    }
}

/**
 * helpful description when debugging
 */
- (NSString*)description {
    if (CGPointEqualToPoint(_startPoint, _ctrl1) && CGPointEqualToPoint(_curveTo, _ctrl2)) {
        return [NSString stringWithFormat:@"[Line from: %f,%f  to: %f,%f]", _startPoint.x, _startPoint.y, _curveTo.x, _curveTo.y];
    } else {
        return [NSString stringWithFormat:@"[Curve from: %f,%f  to: %f,%f]", _startPoint.x, _startPoint.y, _curveTo.x, _curveTo.y];
    }
}


#pragma mark - Helper
/**
 * these bezier functions are licensed and used with permission from http://apptree.net/drawkit.htm
 */

- (void)setColor:(UIColor*)color {
    _color = color;
}

/**
 * will divide a bezier curve into two curves at time t
 * 0 <= t <= 1.0
 *
 * these two curves will exactly match the former single curve
 */
static inline void subdivideBezierAtT(const CGPoint bez[4], CGPoint bez1[4], CGPoint bez2[4], CGFloat t) {
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
static inline void subdivideBezier(const CGPoint bez[4], CGPoint bez1[4], CGPoint bez2[4]) {
    subdivideBezierAtT(bez, bez1, bez2, .5);
}

/**
 * calculates the distance between two points
 */
static inline CGFloat distanceBetween(CGPoint a, CGPoint b) {
    return hypotf(a.x - b.x, a.y - b.y);
}

/**
 * estimates the length along the curve of the
 * input bezier within the input acceptableError
 */
CGFloat jotLengthOfBezier(const CGPoint bez[4], CGFloat acceptableError) {
    CGFloat polyLen = 0.0;
    CGFloat chordLen = distanceBetween(bez[0], bez[3]);
    CGFloat retLen, errLen;
    NSUInteger n;

    for (n = 0; n < 3; ++n)
        polyLen += distanceBetween(bez[n], bez[n + 1]);

    errLen = polyLen - chordLen;

    if (errLen > acceptableError) {
        CGPoint left[4], right[4];
        subdivideBezier(bez, left, right);
        retLen = (jotLengthOfBezier(left, acceptableError) + jotLengthOfBezier(right, acceptableError));
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
static CGFloat subdivideBezierAtLength(const CGPoint bez[4],
                                       CGPoint bez1[4],
                                       CGPoint bez2[4],
                                       CGFloat length,
                                       CGFloat acceptableError,
                                       CGFloat* subBezierlengthCache) {
    CGFloat top = 1.0, bottom = 0.0;
    CGFloat t, prevT;

    prevT = t = 0.5;
    for (;;) {
        CGFloat len1;

        subdivideBezierAtT(bez, bez1, bez2, t);

        int lengthCacheIndex = (int)floorf(t * 1000);
        len1 = subBezierlengthCache[lengthCacheIndex];
        if (!len1) {
            len1 = jotLengthOfBezier(bez1, 0.5 * acceptableError);
            subBezierlengthCache[lengthCacheIndex] = len1;
        }

        if (fabs(length - len1) < acceptableError) {
            return len1;
        }

        if (length > len1) {
            bottom = t;
            t = 0.5 * (t + top);
        } else if (length < len1) {
            top = t;
            t = 0.5 * (bottom + t);
        }

        if (t == prevT) {
            subBezierlengthCache[lengthCacheIndex] = len1;
            return len1;
        }

        prevT = t;
    }
}


#pragma mark - PlistSaving

- (NSDictionary*)asDictionary {
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:[super asDictionary]];
    [dict setObject:[NSNumber numberWithFloat:_curveTo.x] forKey:@"curveTo.x"];
    [dict setObject:[NSNumber numberWithFloat:_curveTo.y] forKey:@"curveTo.y"];
    [dict setObject:[NSNumber numberWithFloat:_ctrl1.x] forKey:@"ctrl1.x"];
    [dict setObject:[NSNumber numberWithFloat:_ctrl1.y] forKey:@"ctrl1.y"];
    [dict setObject:[NSNumber numberWithFloat:_ctrl2.x] forKey:@"ctrl2.x"];
    [dict setObject:[NSNumber numberWithFloat:_ctrl2.y] forKey:@"ctrl2.y"];
    [dict setObject:[NSNumber numberWithBool:_vertexBufferShouldContainColor] forKey:@"vertexBufferShouldContainColor"];
    if (_dataVertexBuffer) {
        [dict setObject:_dataVertexBuffer forKey:@"vertexBuffer"];
    }
    [dict setObject:[NSNumber numberWithFloat:_numberOfBytesOfVertexData] forKey:@"numberOfBytesOfVertexData"];
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (id)initFromDictionary:(NSDictionary*)dictionary {
    self = [super initFromDictionary:dictionary];
    if (self) {
        _lock = [[NSLock alloc] init];
        _boundsCache.origin = JotCGNotFoundPoint;
        _curveTo = CGPointMake([[dictionary objectForKey:@"curveTo.x"] floatValue], [[dictionary objectForKey:@"curveTo.y"] floatValue]);
        _ctrl1 = CGPointMake([[dictionary objectForKey:@"ctrl1.x"] floatValue], [[dictionary objectForKey:@"ctrl1.y"] floatValue]);
        _ctrl2 = CGPointMake([[dictionary objectForKey:@"ctrl2.x"] floatValue], [[dictionary objectForKey:@"ctrl2.y"] floatValue]);
        _dataVertexBuffer = [dictionary objectForKey:@"vertexBuffer"];
        _vertexBufferShouldContainColor = [[dictionary objectForKey:@"vertexBufferShouldContainColor"] boolValue];
        _numberOfBytesOfVertexData = [[dictionary objectForKey:@"numberOfBytesOfVertexData"] integerValue];

        CGFloat currentScale = [[UIScreen mainScreen] scale];
        if (currentScale != _scaleOfVertexBuffer) {
            // the scale of the cached data in the dictionary is
            // different than the scael of the data that we need.
            // zero this out and it'll regenerate with the
            // correct scale on demand
            _scaleOfVertexBuffer = 0;
            _dataVertexBuffer = nil;
            _numberOfBytesOfVertexData = 0;
        }

        if (!_vertexBufferShouldContainColor) {
            [self calculateAndCacheColorComponents];
        }

        NSUInteger prime = 31;
        _hashCache = 1;
        _hashCache = prime * _hashCache + _startPoint.x;
        _hashCache = prime * _hashCache + _startPoint.y;
        _hashCache = prime * _hashCache + _curveTo.x;
        _hashCache = prime * _hashCache + _curveTo.y;
        _hashCache = prime * _hashCache + _ctrl1.x;
        _hashCache = prime * _hashCache + _ctrl1.y;
        _hashCache = prime * _hashCache + _ctrl2.x;
        _hashCache = prime * _hashCache + _ctrl2.y;
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
- (void)validateDataGivenPreviousElement:(AbstractBezierPathElement*)previousElement {
    // noop, we don't have data
    [super validateDataGivenPreviousElement:previousElement];

    NSInteger numberOfBytesThatWeNeed = [self numberOfBytes];
    if (numberOfBytesThatWeNeed != _numberOfBytesOfVertexData) {
        // force reload
        _scaleOfVertexBuffer = 0;
        _dataVertexBuffer = nil;
        _numberOfBytesOfVertexData = 0;
    } else {
        // noop, we're good
    }
}

- (UIBezierPath*)bezierPathSegment {
    UIBezierPath* strokePath = [UIBezierPath bezierPath];
    [strokePath moveToPoint:self.startPoint];
    [strokePath addCurveToPoint:self.endPoint controlPoint1:self.ctrl1 controlPoint2:self.ctrl2];
    return strokePath;
}


#pragma mark - hashing and equality

- (NSUInteger)hash {
    return _hashCache;
}

- (BOOL)isEqual:(id)object {
    return self == object || [self hash] == [object hash];
}

#pragma mark - Scaling

- (void)scaleForWidth:(CGFloat)widthRatio andHeight:(CGFloat)heightRatio {
    [super scaleForWidth:widthRatio andHeight:heightRatio];

    _curveTo.x = _curveTo.x * widthRatio;
    _curveTo.y = _curveTo.y * heightRatio;

    _ctrl1.x = _ctrl1.x * widthRatio;
    _ctrl1.y = _ctrl1.y * heightRatio;

    _ctrl2.x = _ctrl2.x * widthRatio;
    _ctrl2.y = _ctrl2.y * heightRatio;

    _length = 0;

    _dataVertexBuffer = nil;
    if (_vbo) {
        [self.bufferManager recycleBuffer:_vbo];
        _vbo = nil;
    }
}

@end
