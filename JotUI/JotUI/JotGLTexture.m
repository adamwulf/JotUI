//
//  JotGLTexture.m
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import "JotGLTexture.h"
#import "JotUI.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "AbstractBezierPathElement-Protected.h"
#import "JotGLTexture+Private.h"
#import "JotGLQuadProgram.h"


static int totalTextureBytes;


@implementation JotGLTexture {
    CGSize fullPixelSize;
    int fullByteSize;
    NSRecursiveLock* lock;

    int lockCount;
    JotGLContext* contextOfBinding;

    BOOL hasEverSetup;
}

@synthesize textureID;
@synthesize fullByteSize;

+ (int)totalTextureBytes {
    return totalTextureBytes;
}

//
// one option would be to load the dict +
// generate a JotGLTexture at the same time
// on different background threads,
// then when they're both done continue on
// the main thread and ask the drawable view to
// loadImage: andState:
//
// the cost of the archiving can probably be minimized,
// but the cost of generating a CGImage for the texture
// probably can't (b/c i need to inflate the saved PNG
// somewhere.)
//
// this guy might have a much faster way to load a png
// into an opengl texture:
// http://stackoverflow.com/questions/16847680/extract-opengl-raw-rgba-texture-data-from-png-data-stored-in-nsdata-using-libp
//
// https://gist.github.com/joshcodes/5681512
//
// http://iphonedevelopment.blogspot.no/2008/10/iphone-optimized-pngs.html
//
// http://blog.nobel-joergensen.com/2010/11/07/loading-a-png-as-texture-in-opengl-using-libpng/
//
//
// right now, unarchiving is taking longer than loading
// the texture.
// if i can write the texture + load the archive
// in parallel, then i should be able to get a texture
// loaded in ~90ms hopefully.
//

- (id)initForImage:(UIImage*)imageToLoad withSize:(CGSize)size {
    if (self = [super init]) {
        JotGLContext* currContext = (JotGLContext*)[JotGLContext currentContext];
        [JotGLContext runBlock:^(JotGLContext* context) {
            fullPixelSize = size;
            lock = [[NSRecursiveLock alloc] init];
            lockCount = 0;


            fullByteSize = fullPixelSize.width * fullPixelSize.height * 4;
            @synchronized([JotGLTexture class]) {
                totalTextureBytes += fullByteSize;
            }

            //
            // load the image data if we have some, or initialize to
            // a blank texture
            if (imageToLoad) {
                //
                // we have an image to load, so draw it to a bitmap context.
                // then we can load those bytes into OpenGL directly.
                // after they're loaded, we can free the memory for our cgcontext.
                CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                void* imageData = calloc(fullPixelSize.height * fullPixelSize.width, 4);
                if (!imageData) {
                    @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't malloc" userInfo:nil];
                }
                CGContextRef cgContext = CGBitmapContextCreate(imageData, fullPixelSize.width, fullPixelSize.height, 8, 4 * fullPixelSize.width, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
                if (!cgContext) {
                    @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
                }
                CGContextTranslateCTM(cgContext, 0, fullPixelSize.height);
                CGContextScaleCTM(cgContext, 1.0, -1.0);
                CGColorSpaceRelease(colorSpace);
                if (currContext != [JotGLContext currentContext]) {
                    @throw [NSException exceptionWithName:@"OpenGLException" reason:@"Mismatched Context" userInfo:nil];
                }
                CGContextClearRect(cgContext, CGRectMake(0, 0, fullPixelSize.width, fullPixelSize.height));

                // draw the new background in aspect-fill mode
                CGSize backgroundSize = CGSizeMake(CGImageGetWidth(imageToLoad.CGImage), CGImageGetHeight(imageToLoad.CGImage));
                CGFloat horizontalRatio = fullPixelSize.width / backgroundSize.width;
                CGFloat verticalRatio = fullPixelSize.height / backgroundSize.height;
                CGFloat ratio = MAX(horizontalRatio, verticalRatio); //AspectFill
                CGSize aspectFillSize = CGSizeMake(backgroundSize.width * ratio, backgroundSize.height * ratio);

                if (currContext != [JotGLContext currentContext]) {
                    @throw [NSException exceptionWithName:@"OpenGLException" reason:@"Mismatched Context" userInfo:nil];
                }
                CGContextDrawImage(cgContext, CGRectMake((fullPixelSize.width - aspectFillSize.width) / 2,
                                                         (fullPixelSize.height - aspectFillSize.height) / 2,
                                                         aspectFillSize.width,
                                                         aspectFillSize.height),
                                   imageToLoad.CGImage);
                if (currContext != [JotGLContext currentContext]) {
                    @throw [NSException exceptionWithName:@"OpenGLException" reason:@"Mismatched Context" userInfo:nil];
                }


                textureID = [context generateTextureForSize:fullPixelSize withBytes:imageData];

                // cleanup
                CGContextRelease(cgContext);
                free(imageData);
            } else {
                void* zeroedDataCache = calloc(fullPixelSize.height * fullPixelSize.width, 4);
                if (!zeroedDataCache) {
                    @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't malloc" userInfo:nil];
                }
                textureID = [context generateTextureForSize:fullPixelSize withBytes:zeroedDataCache];

                free(zeroedDataCache);
            }
        }];
    }

    return self;
}

- (id)initForTextureID:(GLuint)_textureID withSize:(CGSize)_size {
    if (self = [super init]) {
        fullPixelSize = _size;
        textureID = _textureID;
        lock = [[NSRecursiveLock alloc] init];
        lockCount = 0;
    }
    return self;
}

- (CGSize)pixelSize {
    return fullPixelSize;
}

- (void)deleteAssets {
    if (textureID) {
        [JotGLContext runBlock:^(JotGLContext* context) {
            [context deleteTexture:textureID];
        }];
        textureID = 0;
    }
}

- (void)bind {
    NSAssert([JotGLContext currentContext], @"Must have an active context to bind");
    [JotGLContext runBlock:^(JotGLContext* context) {
        printOpenGLError();
        [lock lock];

        NSAssert(!contextOfBinding || contextOfBinding == [JotGLContext currentContext], @"Our binding context must stay the same");

        lockCount++;
        contextOfBinding = (JotGLContext*)[JotGLContext currentContext];
        // locked this texture while it's bound so that
        // it can't be used elsewhere while in use here
        [context bindTexture:textureID];
        printOpenGLError();
    }];
}

- (void)bindForRenderToQuadWithCanvasSize:(CGSize)canvasSize forProgram:(JotGLQuadProgram*)program {
    program.canvasSize = GLSizeFromCGSize(canvasSize);

    [program use];
    printOpenGLError();
    glBindTexture(GL_TEXTURE_2D, self.textureID);
    printOpenGLError();
    glDisable(GL_CULL_FACE);
    printOpenGLError();
    // TODO: shouldn't this be inside the Program?
    glUniform1i([program uniformTextureIndex], 0);
    printOpenGLError();
}

- (void)rebind {
    // rebinds the texture, while maintaining lock count
    // and lock ownership
    [JotGLContext runBlock:^(JotGLContext* context) {
        if (!lockCount) {
            @throw [NSException exceptionWithName:@"TextureBindException" reason:@"Cannot rebind unbound texture" userInfo:nil];
        }
        [lock lock];
        [self unbind];
        [self bind];
        [lock unlock];
    }];
}

- (void)unbind {
    [JotGLContext runBlock:^(JotGLContext* context) {
        printOpenGLError();
        [context unbindTexture];
        [context flush];
        // unlocked the texture so it'll be free to be used elsewhere
        NSAssert(contextOfBinding == [JotGLContext currentContext], @"Must unbind on the same context that we bound on");
        lockCount--;
        if (lockCount == 0) {
            contextOfBinding = nil;
        }
        [lock unlock];
        printOpenGLError();
    }];
}

/**
 * this will draw the texture at coordinates (0,0)
 * for its full pixel size
 */
- (void)drawInContext:(JotGLContext*)context withCanvasSize:(CGSize)canvasSize {
    [self drawInContext:context atT1:CGPointMake(0, 1)
                  andT2:CGPointMake(1, 1)
                  andT3:CGPointMake(0, 0)
                  andT4:CGPointMake(1, 0)
                   atP1:CGPointMake(0, fullPixelSize.height)
                  andP2:CGPointMake(fullPixelSize.width, fullPixelSize.height)
                  andP3:CGPointMake(0, 0)
                  andP4:CGPointMake(fullPixelSize.width, 0)
         withResolution:fullPixelSize
                andClip:nil
        andClippingSize:CGSizeZero
                asErase:NO
         withCanvasSize:canvasSize]; // default to draw full texture w/o color modification
}


/**
 * this will draw the texture at coordinates (0,0)
 * for its full pixel size
 *
 * Note: https://github.com/adamwulf/loose-leaf/issues/408
 * clipping path is in 1.0 scale, regardless of the context.
 * so it may need to be stretched to fill the size.
 */
- (void)drawInContext:(JotGLContext*)context
                 atT1:(CGPoint)t1
                andT2:(CGPoint)t2
                andT3:(CGPoint)t3
                andT4:(CGPoint)t4
                 atP1:(CGPoint)p1
                andP2:(CGPoint)p2
                andP3:(CGPoint)p3
                andP4:(CGPoint)p4
       withResolution:(CGSize)resolution
              andClip:(UIBezierPath*)clippingPath
      andClippingSize:(CGSize)clipSize
              asErase:(BOOL)asErase
       withCanvasSize:(CGSize)canvasSize {
    // save our clipping texture and stencil buffer, if any
    [JotGLContext runBlock:^(JotGLContext* context) {

        //
        // prep our context to draw our texture as a quad.
        // now prep to draw the actual texture
        // always draw

        void (^possiblyStenciledRenderBlock)(void) = ^{

            [context prepOpenGLBlendModeForColor:asErase ? nil : [UIColor whiteColor]];

            //
            // these vertices make sure to draw our texture across
            // the entire size, with the input texture coordinates.
            //
            // this allows the caller to ask us to render a portion of our
            // texture in any size rect it needs
            Vertex3D squareVertices[] = {
                {p1.x, p1.y},
                {p2.x, p2.y},
                {p3.x, p3.y},
                {p4.x, p4.y}};
            const GLfloat textureVertices[] = {
                t1.x, t1.y,
                t2.x, t2.y,
                t3.x, t3.y,
                t4.x, t4.y};

            // now draw our own texture, which will be drawn
            // for only the input texture coords and will respect
            // the stencil, if any
            [self bind];

            [self bindForRenderToQuadWithCanvasSize:canvasSize forProgram:[context quadProgram]];


            [context enableVertexArrayAtIndex:[[context quadProgram] attributePositionIndex] forSize:2 andStride:0 andPointer:squareVertices];
            [context enableTextureCoordArrayAtIndex:[[context quadProgram] attributeTextureCoordinateIndex] forSize:2 andStride:0 andPointer:textureVertices];
            [context drawTriangleStripCount:4 withProgram:[context quadProgram]];
        };

        // cleanup
        [context runBlock:possiblyStenciledRenderBlock
            forStenciledPath:clippingPath
                        atP1:p1
                       andP2:p2
                       andP3:p3
                       andP4:p4
             andClippingSize:clipSize
              withResolution:resolution
             withVertexIndex:[[context quadProgram] attributePositionIndex]
             andTextureIndex:[[context quadProgram] attributeTextureCoordinateIndex]];

        [self unbind];
    }];
}


- (BOOL)isLocked {
    return lockCount != 0;
}

- (void)dealloc {
    [lock lock];
    NSAssert([JotGLContext currentContext] != nil, @"must be on glcontext");
    @synchronized([JotGLTexture class]) {
        totalTextureBytes -= fullByteSize;
    }
    [self deleteAssets];
    [lock unlock];
}


@end
