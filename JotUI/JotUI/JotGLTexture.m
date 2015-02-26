//
//  JotGLTexture.m
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLTexture.h"
#import "JotUI.h"
#import "JotGLContext.h"
#import "AbstractBezierPathElement-Protected.h"

static int totalTextureBytes;

@implementation JotGLTexture{
    CGSize fullPixelSize;
    int fullByteSize;
    NSRecursiveLock* lock;

    int lockCount;
    JotGLContext* contextOfBinding;
}

@synthesize textureID;
@synthesize fullByteSize;

+(int) totalTextureBytes{
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

-(id) initForImage:(UIImage*)imageToLoad withSize:(CGSize)size{
    if(self = [super init]){
        JotGLContext* currContext = (JotGLContext*) [JotGLContext currentContext];
        [JotGLContext runBlock:^(JotGLContext* context){
            fullPixelSize = size;
            lock = [[NSRecursiveLock alloc] init];
            lockCount = 0;
            
            fullByteSize = fullPixelSize.width * fullPixelSize.height * 4;
            @synchronized([JotGLTexture class]){
                totalTextureBytes += fullByteSize;
            }

            //
            // load the image data if we have some, or initialize to
            // a blank texture
            if(imageToLoad){
                //
                // we have an image to load, so draw it to a bitmap context.
                // then we can load those bytes into OpenGL directly.
                // after they're loaded, we can free the memory for our cgcontext.
                CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                void* imageData = calloc(fullPixelSize.height * fullPixelSize.width, 4);
                if(!imageData){
                    @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't malloc" userInfo:nil];
                }
                CGContextRef cgContext = CGBitmapContextCreate( imageData, fullPixelSize.width, fullPixelSize.height, 8, 4 * fullPixelSize.width, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
                if(!cgContext){
                    @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
                }
                CGContextTranslateCTM (cgContext, 0, fullPixelSize.height);
                CGContextScaleCTM (cgContext, 1.0, -1.0);
                CGColorSpaceRelease( colorSpace );
                if(currContext != [JotGLContext currentContext]){
                    DebugLog(@"freak out");
                    @throw [NSException exceptionWithName:@"OpenGLException" reason:@"Mismatched Context" userInfo:nil];
                }
                CGContextClearRect( cgContext, CGRectMake( 0, 0, fullPixelSize.width, fullPixelSize.height ) );
                
                // draw the new background in aspect-fill mode
                CGSize backgroundSize = CGSizeMake(CGImageGetWidth(imageToLoad.CGImage), CGImageGetHeight(imageToLoad.CGImage));
                CGFloat horizontalRatio = fullPixelSize.width / backgroundSize.width;
                CGFloat verticalRatio = fullPixelSize.height / backgroundSize.height;
                CGFloat ratio = MAX(horizontalRatio, verticalRatio); //AspectFill
                CGSize aspectFillSize = CGSizeMake(backgroundSize.width * ratio, backgroundSize.height * ratio);
                
                if(currContext != [JotGLContext currentContext]){
                    @throw [NSException exceptionWithName:@"OpenGLException" reason:@"Mismatched Context" userInfo:nil];
                }
                CGContextDrawImage( cgContext,  CGRectMake((fullPixelSize.width-aspectFillSize.width)/2,
                                                           (fullPixelSize.height-aspectFillSize.height)/2,
                                                           aspectFillSize.width,
                                                           aspectFillSize.height), imageToLoad.CGImage );
                if(currContext != [JotGLContext currentContext]){
                    @throw [NSException exceptionWithName:@"OpenGLException" reason:@"Mismatched Context" userInfo:nil];
                }
                
                // ok, initialize the data
                textureID = [context generateTextureForSize:fullPixelSize withBytes:NULL];
                
                // cleanup
                CGContextRelease(cgContext);
                free(imageData);
            }else{
                void* zeroedDataCache = calloc(fullPixelSize.height * fullPixelSize.width, 4);
                if(!zeroedDataCache){
                    @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't malloc" userInfo:nil];
                }
                textureID = [context generateTextureForSize:fullPixelSize withBytes:zeroedDataCache];
                free(zeroedDataCache);
            }
        }];
    }
    
    return self;
}

-(id) initForTextureID:(GLuint)_textureID withSize:(CGSize)_size{
    if(self = [super init]){
        fullPixelSize = _size;
        textureID = _textureID;
        lock = [[NSRecursiveLock alloc] init];
        lockCount = 0;
    }
    return self;
}

-(CGSize) pixelSize{
    return fullPixelSize;
}

-(void) deleteAssets{
    if (textureID){
        [JotGLContext runBlock:^(JotGLContext *context) {
            [context deleteTexture:textureID];
        }];
        textureID = 0;
    }
}

-(void) bind{
    if(![JotGLContext currentContext]){
        NSLog(@"what");
    }
    [JotGLContext runBlock:^(JotGLContext* context){
        printOpenGLError();
        [lock lock];
        
        if(contextOfBinding != nil && contextOfBinding != [JotGLContext currentContext]){
            DebugLog(@"gotcha");
        }
        lockCount++;
        contextOfBinding = (JotGLContext*) [JotGLContext currentContext];
        //    DebugLog(@"locked %p (%d)", self, self.textureID);
        if(textureID){
            [context bindTexture:textureID];
        }else{
            DebugLog(@"what4");
        }
        printOpenGLError();
    }];
}

-(void) unbind{
    [JotGLContext runBlock:^(JotGLContext* context){
        printOpenGLError();
        [context unbindTexture];
        [context flush];
        //    DebugLog(@"unlocked %p (%d)", self, self.textureID);
        if(contextOfBinding != [JotGLContext currentContext]){
            DebugLog(@"gotcha");
        }
        lockCount--;
        if(lockCount == 0){
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
-(void) drawInContext:(JotGLContext*)context{
    [self drawInContext:context atT1:CGPointMake(0, 1)
                  andT2:CGPointMake(1, 1)
                  andT3:CGPointMake(0, 0)
                  andT4:CGPointMake(1, 0)
                   atP1:CGPointMake(0, fullPixelSize.height)
                  andP2:CGPointMake(fullPixelSize.width, fullPixelSize.height)
                  andP3:CGPointMake(0,0)
                  andP4:CGPointMake(fullPixelSize.width, 0)
         withResolution:fullPixelSize
                andClip:nil
        andClippingSize:CGSizeZero
              asErase:NO]; // default to draw full texture w/o color modification
}


/**
 * this will draw the texture at coordinates (0,0)
 * for its full pixel size
 *
 * Note: https://github.com/adamwulf/loose-leaf/issues/408
 * clipping path is in 1.0 scale, regardless of the context.
 * so it may need to be stretched to fill the size.
 */
-(void) drawInContext:(JotGLContext*)context
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
            asErase:(BOOL)asErase{
    // save our clipping texture and stencil buffer, if any
    [JotGLContext runBlock:^(JotGLContext* context){
        
        //
        // prep our context to draw our texture as a quad.
        // now prep to draw the actual texture
        // always draw
        
        void(^possiblyStenciledRenderBlock)() = ^{
            
            [context disableColorArray];
            [context disablePointSizeArray];
            [context glColor4f:1 and:1 and:1 and:1];
            
            [context prepOpenGLBlendModeForColor:asErase ? nil : [UIColor whiteColor]];
            
            //
            // these vertices make sure to draw our texture across
            // the entire size, with the input texture coordinates.
            //
            // this allows the caller to ask us to render a portion of our
            // texture in any size rect it needs
            Vertex3D vertices[] = {
                { p1.x, p1.y},
                { p2.x, p2.y},
                { p3.x, p3.y},
                { p4.x, p4.y}
            };
            const GLfloat texCoords[] = {
                t1.x, t1.y,
                t2.x, t2.y,
                t3.x, t3.y,
                t4.x, t4.y
            };
            // now draw our own texture, which will be drawn
            // for only the input texture coords and will respect
            // the stencil, if any
            [self bind];
            [context enableVertexArrayForSize:2 andStride:0 andPointer:vertices];
            [context enableTextureCoordArrayForSize:2 andStride:0 andPointer:texCoords];
            [context drawTriangleStripCount:4];
        };
        
        // cleanup
        if(clippingPath){
            [context runBlock:possiblyStenciledRenderBlock
             forStenciledPath:clippingPath
                         atP1:p1
                        andP2:p2
                        andP3:p3
                        andP4:p4
              andClippingSize:clipSize
               withResolution:resolution];
        }else{
            possiblyStenciledRenderBlock();
        }
        [self unbind];
    }];
}

-(void) dealloc{
    @synchronized([JotGLTexture class]){
        totalTextureBytes -= fullByteSize;
    }
	[self deleteAssets];
}

@end
