//
//  FilledPathElement.m
//  JotUI
//
//  Created by Adam Wulf on 2/5/14.
//  Copyright (c) 2014 Milestone Made. All rights reserved.
//

#import "FilledPathElement.h"
#import "AbstractBezierPathElement-Protected.h"
#import <MessageUI/MFMailComposeViewController.h>


@implementation FilledPathElement {
    // cache the hash, since it's expenseive to calculate
    NSUInteger hashCache;
    // bezier path
    UIBezierPath* path;
    // create texture
    JotGLTexture* texture;
    //
    CGPoint p1;
    CGPoint p2;
    CGPoint p3;
    CGPoint p4;

    CGFloat scaleToDraw;
    CGAffineTransform scaleTransform;

    CGSize sizeOfTexture;

    NSLock* lock;
}

- (UIColor*)color {
    return [UIColor blackColor];
}


- (id)initWithPath:(UIBezierPath*)_path andP1:(CGPoint)_p1 andP2:(CGPoint)_p2 andP3:(CGPoint)_p3 andP4:(CGPoint)_p4 andSize:(CGSize)size {
    if (self = [super initWithStart:CGPointZero]) {
        lock = [[NSLock alloc] init];
        path = [_path copy];
        path.lineWidth = 2;
        sizeOfTexture = size;

        p1 = _p1;
        p2 = _p2;
        p3 = _p3;
        p4 = _p4;

        NSUInteger prime = 31;
        hashCache = 1;
        hashCache = prime * hashCache + p1.x;
        hashCache = prime * hashCache + p1.y;
        hashCache = prime * hashCache + p2.x;
        hashCache = prime * hashCache + p2.y;
        hashCache = prime * hashCache + p3.x;
        hashCache = prime * hashCache + p3.y;
        hashCache = prime * hashCache + p4.x;
        hashCache = prime * hashCache + p4.y;

        [self generateTextureFromPath];

        scaleToDraw = 1.0;
        scaleTransform = CGAffineTransformIdentity;
    }
    return self;
}

+ (id)elementWithPath:(UIBezierPath*)path andP1:(CGPoint)_p1 andP2:(CGPoint)_p2 andP3:(CGPoint)_p3 andP4:(CGPoint)_p4 andSize:(CGSize)size {
    return [[FilledPathElement alloc] initWithPath:path andP1:_p1 andP2:_p2 andP3:_p3 andP4:_p4 andSize:(CGSize)size];
}


- (void)generateTextureFromPath {
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, sizeOfTexture.width, sizeOfTexture.height, 8, sizeOfTexture.width * 4, colorspace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    if (!bitmapContext) {
        @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
    }

    UIGraphicsPushContext(bitmapContext);

    CGContextClearRect(bitmapContext, CGRectMake(0, 0, sizeOfTexture.width, sizeOfTexture.height));

    // flip vertical for our drawn content, since OpenGL is opposite core graphics
    CGContextTranslateCTM(bitmapContext, 0, sizeOfTexture.height);
    CGContextScaleCTM(bitmapContext, 1.0, -1.0);

    //
    // ok, now render our actual content
    CGContextClearRect(bitmapContext, CGRectMake(0.0, 0.0, sizeOfTexture.width, sizeOfTexture.height));
    [[UIColor whiteColor] setFill];
    [path fill];

    // Retrieve the UIImage from the current context
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    if (!cgImage) {
        @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
    }

    UIImage* image = [UIImage imageWithCGImage:cgImage scale:1.0 orientation:UIImageOrientationUp];

    // Clean up
    CFRelease(colorspace);
    UIGraphicsPopContext();
    CGContextRelease(bitmapContext);

    // ok, we're done exporting and cleaning up
    // so pass the newly generated image to the completion block
    texture = [[JotGLTexture alloc] initForImage:image withSize:image.size];
    CGImageRelease(cgImage);
}

- (int)fullByteSize {
    return texture.fullByteSize;
}

/**
 * the length along the curve of this element.
 * since it's a curve, this will be longer than
 * the straight distance between start/end points
 */
- (CGFloat)lengthOfElement {
    return 0;
}

- (CGRect)bounds {
    CGPoint origin = CGPointMake(MIN(p1.x, MIN(p2.x, MIN(p3.x, p4.x))), MIN(p1.y, MIN(p2.y, MIN(p3.y, p4.y))));
    CGPoint maxP = CGPointMake(MAX(p1.x, MAX(p2.x, MAX(p3.x, p4.x))), MAX(p1.y, MAX(p2.y, MAX(p3.y, p4.y))));
    return CGRectMake(origin.x, origin.y, maxP.x - origin.x, maxP.y - origin.y);
}


- (NSInteger)numberOfBytesGivenPreviousElement:(AbstractBezierPathElement*)previousElement {
    // find out how many steps we can put inside this segment length
    return 0;
}

/**
 * generate a vertex buffer array for all of the points
 * along this curve for the input scale.
 *
 * this method will cache the array for a single scale. if
 * a new scale is sent in later, then the cache will be rebuilt
 * for the new scale.
 */
- (struct ColorfulVertex*)generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale {
    scaleToDraw = scale;
    scaleTransform = CGAffineTransformMakeScale(scaleToDraw, scaleToDraw);
    return nil;
}


- (void)loadDataIntoVBOIfNeeded {
    // noop
}


- (void)drawGivenPreviousElement:(AbstractBezierPathElement*)previousElement {
    [self bind];

    CGSize screenSize = [[[UIScreen mainScreen] fixedCoordinateSpace] bounds].size;
    screenSize.width *= [[UIScreen mainScreen] scale];
    screenSize.height *= [[UIScreen mainScreen] scale];

    [texture drawInContext:(JotGLContext*)[JotGLContext currentContext]
                      atT1:CGPointMake(0, 1)
                     andT2:CGPointMake(1, 1)
                     andT3:CGPointMake(0, 0)
                     andT4:CGPointMake(1, 0)
                      atP1:CGPointApplyAffineTransform(p1, scaleTransform)
                     andP2:CGPointApplyAffineTransform(p2, scaleTransform)
                     andP3:CGPointApplyAffineTransform(p3, scaleTransform)
                     andP4:CGPointApplyAffineTransform(p4, scaleTransform)
            withResolution:texture.pixelSize
                   andClip:nil
           andClippingSize:CGSizeZero
                   asErase:YES
            withCanvasSize:screenSize]; // erase

    //
    // should make a drawInQuad: method that takes four points
    // i can just translate the mmscrap corners into the main page
    // coordinates, and send these four points into the draw call
    //
    // will also need to set the blend mode to make it erase instead of
    // draw, once i have the location in the right place
    [self unbind];
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
    if (![lock tryLock]) {
        [lock lock];
    }
    [texture bind];
    return YES;
}

- (void)unbind {
    [texture unbind];
    [lock unlock];
}


- (void)dealloc {
    [[JotTrashManager sharedInstance] addObjectToDealloc:texture];
    texture = nil;
}

/**
 * helpful description when debugging
 */
- (NSString*)description {
    return @"[FilledPathSegment]";
}


#pragma mark - PlistSaving

- (NSDictionary*)asDictionary {
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:[super asDictionary]];

    [dict setObject:[NSKeyedArchiver archivedDataWithRootObject:path] forKey:@"bezierPath"];

    [dict setObject:[NSNumber numberWithFloat:p1.x] forKey:@"p1.x"];
    [dict setObject:[NSNumber numberWithFloat:p1.y] forKey:@"p1.y"];
    [dict setObject:[NSNumber numberWithFloat:p2.x] forKey:@"p2.x"];
    [dict setObject:[NSNumber numberWithFloat:p2.y] forKey:@"p2.y"];
    [dict setObject:[NSNumber numberWithFloat:p3.x] forKey:@"p3.x"];
    [dict setObject:[NSNumber numberWithFloat:p3.y] forKey:@"p3.y"];
    [dict setObject:[NSNumber numberWithFloat:p4.x] forKey:@"p4.x"];
    [dict setObject:[NSNumber numberWithFloat:p4.y] forKey:@"p4.y"];
    [dict setObject:[NSNumber numberWithFloat:sizeOfTexture.width] forKey:@"sizeOfTexture.width"];
    [dict setObject:[NSNumber numberWithFloat:sizeOfTexture.height] forKey:@"sizeOfTexture.height"];

    return [NSDictionary dictionaryWithDictionary:dict];
}

- (id)initFromDictionary:(NSDictionary*)dictionary {
    self = [super initFromDictionary:dictionary];
    if (self) {
        lock = [[NSLock alloc] init];
        // load from dictionary
        path = [NSKeyedUnarchiver unarchiveObjectWithData:[dictionary objectForKey:@"bezierPath"]];
        p1 = CGPointMake([[dictionary objectForKey:@"p1.x"] floatValue], [[dictionary objectForKey:@"p1.y"] floatValue]);
        p2 = CGPointMake([[dictionary objectForKey:@"p2.x"] floatValue], [[dictionary objectForKey:@"p2.y"] floatValue]);
        p3 = CGPointMake([[dictionary objectForKey:@"p3.x"] floatValue], [[dictionary objectForKey:@"p3.y"] floatValue]);
        p4 = CGPointMake([[dictionary objectForKey:@"p4.x"] floatValue], [[dictionary objectForKey:@"p4.y"] floatValue]);
        sizeOfTexture = CGSizeMake([[dictionary objectForKey:@"sizeOfTexture.width"] floatValue], [[dictionary objectForKey:@"sizeOfTexture.height"] floatValue]);

        //        CGFloat currentScale = [[dictionary objectForKey:@"scale"] floatValue];
        // we can ignore the scale that's sent in because
        // we set the scaleTransform on demand, and keep all pts
        // of this element in pts instead of pxs

        NSUInteger prime = 31;
        hashCache = 1;
        hashCache = prime * hashCache + p1.x;
        hashCache = prime * hashCache + p1.y;
        hashCache = prime * hashCache + p2.x;
        hashCache = prime * hashCache + p2.y;
        hashCache = prime * hashCache + p3.x;
        hashCache = prime * hashCache + p3.y;
        hashCache = prime * hashCache + p4.x;
        hashCache = prime * hashCache + p4.y;

        [self generateTextureFromPath];
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
    // noop
}

- (UIBezierPath*)bezierPathSegment {
    return path;
}


#pragma mark - hashing and equality

- (NSUInteger)hash {
    return hashCache;
}

- (BOOL)isEqual:(id)object {
    return self == object || [self hash] == [object hash];
}


#pragma mark - Scaling

- (void)scaleForWidth:(CGFloat)widthRatio andHeight:(CGFloat)heightRatio {
    [super scaleForWidth:widthRatio andHeight:heightRatio];

    p1.x = p1.x * widthRatio;
    p1.y = p1.y * heightRatio;

    p2.x = p2.x * widthRatio;
    p2.y = p2.y * heightRatio;

    p3.x = p3.x * widthRatio;
    p3.y = p3.y * heightRatio;

    p4.x = p4.x * widthRatio;
    p4.y = p4.y * heightRatio;
}

@end
