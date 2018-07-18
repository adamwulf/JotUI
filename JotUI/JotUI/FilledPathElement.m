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
    NSUInteger _hashCache;
    // bezier path
    UIBezierPath* _path;
    // create texture
    JotGLTexture* _texture;
    //
    CGPoint _p1;
    CGPoint _p2;
    CGPoint _p3;
    CGPoint _p4;

    CGFloat _scaleToDraw;
    CGAffineTransform _scaleTransform;

    CGSize _sizeOfTexture;

    NSLock* _lock;
}

- (UIColor*)color {
    return [UIColor blackColor];
}


- (id)initWithPath:(UIBezierPath*)path andP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4 andSize:(CGSize)size {
    if (self = [super initWithStart:CGPointZero]) {
        _lock = [[NSLock alloc] init];
        _path = [path copy];
        _path.lineWidth = 2;
        _sizeOfTexture = size;

        _p1 = p1;
        _p2 = p2;
        _p3 = p3;
        _p4 = p4;

        NSUInteger prime = 31;
        _hashCache = 1;
        _hashCache = prime * _hashCache + _p1.x;
        _hashCache = prime * _hashCache + _p1.y;
        _hashCache = prime * _hashCache + _p2.x;
        _hashCache = prime * _hashCache + _p2.y;
        _hashCache = prime * _hashCache + _p3.x;
        _hashCache = prime * _hashCache + _p3.y;
        _hashCache = prime * _hashCache + _p4.x;
        _hashCache = prime * _hashCache + _p4.y;

        [self generateTextureFromPath];

        _scaleToDraw = 1.0;
        _scaleTransform = CGAffineTransformIdentity;
    }
    return self;
}

+ (id)elementWithPath:(UIBezierPath*)path andP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4 andSize:(CGSize)size {
    return [[FilledPathElement alloc] initWithPath:path andP1:p1 andP2:p2 andP3:p3 andP4:p4 andSize:(CGSize)size];
}


- (void)generateTextureFromPath {
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, _sizeOfTexture.width, _sizeOfTexture.height, 8, _sizeOfTexture.width * 4, colorspace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    if (!bitmapContext) {
        @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
    }

    UIGraphicsPushContext(bitmapContext);

    CGContextClearRect(bitmapContext, CGRectMake(0, 0, _sizeOfTexture.width, _sizeOfTexture.height));

    // flip vertical for our drawn content, since OpenGL is opposite core graphics
    CGContextTranslateCTM(bitmapContext, 0, _sizeOfTexture.height);
    CGContextScaleCTM(bitmapContext, 1.0, -1.0);

    //
    // ok, now render our actual content
    CGContextClearRect(bitmapContext, CGRectMake(0.0, 0.0, _sizeOfTexture.width, _sizeOfTexture.height));
    [[UIColor whiteColor] setFill];
    [_path fill];

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
    _texture = [[JotGLTexture alloc] initForImage:image withSize:image.size];
    CGImageRelease(cgImage);
}

- (int)fullByteSize {
    return _texture.fullByteSize;
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
    CGPoint origin = CGPointMake(MIN(_p1.x, MIN(_p2.x, MIN(_p3.x, _p4.x))), MIN(_p1.y, MIN(_p2.y, MIN(_p3.y, _p4.y))));
    CGPoint maxP = CGPointMake(MAX(_p1.x, MAX(_p2.x, MAX(_p3.x, _p4.x))), MAX(_p1.y, MAX(_p2.y, MAX(_p3.y, _p4.y))));
    return CGRectMake(origin.x, origin.y, maxP.x - origin.x, maxP.y - origin.y);
}


- (NSInteger)numberOfBytes {
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
- (struct ColorfulVertex*)generatedVertexArrayForScale:(CGFloat)scale {
    _scaleToDraw = scale;
    _scaleTransform = CGAffineTransformMakeScale(_scaleToDraw, _scaleToDraw);
    return nil;
}


- (void)loadDataIntoVBOIfNeeded {
    // noop
}


- (void)draw {
    [self bind];

    CGSize screenSize = [[[UIScreen mainScreen] fixedCoordinateSpace] bounds].size;
    screenSize.width *= [[UIScreen mainScreen] scale];
    screenSize.height *= [[UIScreen mainScreen] scale];

    [_texture drawInContext:(JotGLContext*)[JotGLContext currentContext]
                       atT1:CGPointMake(0, 1)
                      andT2:CGPointMake(1, 1)
                      andT3:CGPointMake(0, 0)
                      andT4:CGPointMake(1, 0)
                       atP1:CGPointApplyAffineTransform(_p1, _scaleTransform)
                      andP2:CGPointApplyAffineTransform(_p2, _scaleTransform)
                      andP3:CGPointApplyAffineTransform(_p3, _scaleTransform)
                      andP4:CGPointApplyAffineTransform(_p4, _scaleTransform)
             withResolution:_texture.pixelSize
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
    if (![_lock tryLock]) {
        [_lock lock];
    }
    [_texture bind];
    return YES;
}

- (void)unbind {
    [_texture unbind];
    [_lock unlock];
}


- (void)dealloc {
    [[JotTrashManager sharedInstance] addObjectToDealloc:_texture];
    _texture = nil;
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

    [dict setObject:[NSKeyedArchiver archivedDataWithRootObject:_path] forKey:@"bezierPath"];

    [dict setObject:[NSNumber numberWithFloat:_p1.x] forKey:@"p1.x"];
    [dict setObject:[NSNumber numberWithFloat:_p1.y] forKey:@"p1.y"];
    [dict setObject:[NSNumber numberWithFloat:_p2.x] forKey:@"p2.x"];
    [dict setObject:[NSNumber numberWithFloat:_p2.y] forKey:@"p2.y"];
    [dict setObject:[NSNumber numberWithFloat:_p3.x] forKey:@"p3.x"];
    [dict setObject:[NSNumber numberWithFloat:_p3.y] forKey:@"p3.y"];
    [dict setObject:[NSNumber numberWithFloat:_p4.x] forKey:@"p4.x"];
    [dict setObject:[NSNumber numberWithFloat:_p4.y] forKey:@"p4.y"];
    [dict setObject:[NSNumber numberWithFloat:_sizeOfTexture.width] forKey:@"sizeOfTexture.width"];
    [dict setObject:[NSNumber numberWithFloat:_sizeOfTexture.height] forKey:@"sizeOfTexture.height"];

    return [NSDictionary dictionaryWithDictionary:dict];
}

- (id)initFromDictionary:(NSDictionary*)dictionary {
    self = [super initFromDictionary:dictionary];
    if (self) {
        _lock = [[NSLock alloc] init];
        // load from dictionary
        _path = [NSKeyedUnarchiver unarchiveObjectWithData:[dictionary objectForKey:@"bezierPath"]];
        _p1 = CGPointMake([[dictionary objectForKey:@"p1.x"] floatValue], [[dictionary objectForKey:@"p1.y"] floatValue]);
        _p2 = CGPointMake([[dictionary objectForKey:@"p2.x"] floatValue], [[dictionary objectForKey:@"p2.y"] floatValue]);
        _p3 = CGPointMake([[dictionary objectForKey:@"p3.x"] floatValue], [[dictionary objectForKey:@"p3.y"] floatValue]);
        _p4 = CGPointMake([[dictionary objectForKey:@"p4.x"] floatValue], [[dictionary objectForKey:@"p4.y"] floatValue]);
        _sizeOfTexture = CGSizeMake([[dictionary objectForKey:@"sizeOfTexture.width"] floatValue], [[dictionary objectForKey:@"sizeOfTexture.height"] floatValue]);

        //        CGFloat currentScale = [[dictionary objectForKey:@"scale"] floatValue];
        // we can ignore the scale that's sent in because
        // we set the scaleTransform on demand, and keep all pts
        // of this element in pts instead of pxs

        NSUInteger prime = 31;
        _hashCache = 1;
        _hashCache = prime * _hashCache + _p1.x;
        _hashCache = prime * _hashCache + _p1.y;
        _hashCache = prime * _hashCache + _p2.x;
        _hashCache = prime * _hashCache + _p2.y;
        _hashCache = prime * _hashCache + _p3.x;
        _hashCache = prime * _hashCache + _p3.y;
        _hashCache = prime * _hashCache + _p4.x;
        _hashCache = prime * _hashCache + _p4.y;

        [self generateTextureFromPath];
    }
    return self;
}

- (UIBezierPath*)bezierPathSegment {
    return _path;
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

    _p1.x = _p1.x * widthRatio;
    _p1.y = _p1.y * heightRatio;

    _p2.x = _p2.x * widthRatio;
    _p2.y = _p2.y * heightRatio;

    _p3.x = _p3.x * widthRatio;
    _p3.y = _p3.y * heightRatio;

    _p4.x = _p4.x * widthRatio;
    _p4.y = _p4.y * heightRatio;
}

@end
