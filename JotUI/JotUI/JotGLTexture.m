//
//  JotGLTexture.m
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLTexture.h"
#import "JotUI.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

static int totalTextureBytes;

@implementation JotGLTexture{
    CGSize fullPixelSize;
    int fullByteSize;
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
        fullPixelSize = size;
        
        // unload the old texture
        [self deleteAssets];
        
        // create a new texture in OpenGL
        glGenTextures(1, &textureID);
        
        // bind the texture that we'll be writing to
        glBindTexture(GL_TEXTURE_2D, textureID);
        
        // configure how this texture scales.
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
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
                NSLog(@"freak out");
            }
            CGContextClearRect( cgContext, CGRectMake( 0, 0, fullPixelSize.width, fullPixelSize.height ) );
            
            // draw the new background in aspect-fill mode
            CGSize backgroundSize = CGSizeMake(CGImageGetWidth(imageToLoad.CGImage), CGImageGetHeight(imageToLoad.CGImage));
            CGFloat horizontalRatio = fullPixelSize.width / backgroundSize.width;
            CGFloat verticalRatio = fullPixelSize.height / backgroundSize.height;
            CGFloat ratio = MAX(horizontalRatio, verticalRatio); //AspectFill
            CGSize aspectFillSize = CGSizeMake(backgroundSize.width * ratio, backgroundSize.height * ratio);
            
            if(currContext != [JotGLContext currentContext]){
                NSLog(@"freak out");
            }
            CGContextDrawImage( cgContext,  CGRectMake((fullPixelSize.width-aspectFillSize.width)/2,
                                                       (fullPixelSize.height-aspectFillSize.height)/2,
                                                       aspectFillSize.width,
                                                       aspectFillSize.height), imageToLoad.CGImage );
            if(currContext != [JotGLContext currentContext]){
                NSLog(@"freak out");
            }
            // ok, initialize the data
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fullPixelSize.width, fullPixelSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
            
            // cleanup
            CGContextRelease(cgContext);
            free(imageData);
        }else{
            void* zeroedDataCache = calloc(fullPixelSize.height * fullPixelSize.width, 4);
            if(!zeroedDataCache){
                @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't malloc" userInfo:nil];
            }
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fullPixelSize.width, fullPixelSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, zeroedDataCache);
            free(zeroedDataCache);
        }
        // clear texture bind
        glBindTexture(GL_TEXTURE_2D,0);
        
        JotGLContext* context = (JotGLContext*)[JotGLContext currentContext];
        [context flush];
    }
    
    return self;
}

-(id) initForTextureID:(GLuint)_textureID withSize:(CGSize)_size{
    if(self = [super init]){
        fullPixelSize = _size;
        textureID = _textureID;
    }
    return self;
}

-(CGSize) pixelSize{
    return fullPixelSize;
}

-(void) deleteAssets{
    if (textureID){
        glDeleteTextures(1, &textureID);
        textureID = 0;
    }
}

-(void) bind{
    if(textureID){
        glBindTexture(GL_TEXTURE_2D, textureID);
    }else{
        NSLog(@"what4");
    }
}

-(void) unbind{
    glBindTexture(GL_TEXTURE_2D, 0);
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
       withResolution:(CGSize)size
              andClip:(UIBezierPath*)clippingPath
      andClippingSize:(CGSize)clipSize
            asErase:(BOOL)asErase{
    // save our clipping texture and stencil buffer, if any
    JotGLTexture* clipping;
    GLuint stencil_rb;
    
    [JotGLContext validateContextMatches:context];
    
    if(clippingPath){
        
        CGSize pathSize = clippingPath.bounds.size;
        pathSize.width = ceilf(pathSize.width);
        pathSize.height = ceilf(pathSize.height);
        
        // on high res screens, the input path is in
        // pt instead of px, so we need to make sure
        // the clipping texture is in the same coordinate
        // space as the gl context. to do that build
        // a texture that matches the path's bounds, and
        // it'll stretch to fill the context.
        //
        // https://github.com/adamwulf/loose-leaf/issues/408
        //
        // generate simple coregraphics texture in coregraphics
        UIGraphicsBeginImageContextWithOptions(clipSize, NO, 1);
        CGContextRef cgContext = UIGraphicsGetCurrentContext();
        CGContextClearRect(cgContext, CGRectMake(0, 0, clipSize.width, clipSize.height));
        [[UIColor whiteColor] setFill];
        [clippingPath fill];
        CGContextSetBlendMode(cgContext, kCGBlendModeClear);
        CGContextSetBlendMode(cgContext, kCGBlendModeNormal);
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        // this is an image that's filled white with our path and
        // clear everywhere else
        clipping = [[JotGLTexture alloc] initForImage:image withSize:image.size];
    }
    
    //
    // prep our context to draw our texture as a quad.
    // now prep to draw the actual texture
    // always draw
    [context glEnableClientState:GL_VERTEX_ARRAY];
    [context glDisableClientState:GL_COLOR_ARRAY];
    [context glDisableClientState:GL_POINT_SIZE_ARRAY_OES];
    [context glEnableClientState:GL_TEXTURE_COORD_ARRAY];
    [context glColor4f:1 and:1 and:1 and:1];

    GLint currBoundRendBuff = -1;
    glGetIntegerv(GL_RENDERBUFFER_BINDING_OES, &currBoundRendBuff);

    // if we were provided a clippingPath, then we should
    // use it as our stencil when drawing our texture
    if(clippingPath){
        // always draw to stencil with correct blend mode
        [context glBlendFunc:GL_ONE and:GL_ONE_MINUS_SRC_ALPHA];
        // setup stencil buffers
        glGenRenderbuffersOES(1, &stencil_rb);
//        NSLog(@"new renderbuffer: %d", stencil_rb);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, stencil_rb);
        glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_STENCIL_INDEX8_OES, size.width, size.height);
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_STENCIL_ATTACHMENT_OES, GL_RENDERBUFFER_OES, stencil_rb);
        
        // Check framebuffer completeness at the end of initialization.
        GLuint status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
        if (status != GL_FRAMEBUFFER_COMPLETE_OES){
            // didn't work
            NSString* str = [NSString stringWithFormat:@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)];
            NSLog(@"%@", str);
            @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:str userInfo:nil];
        }

        // setup the stencil test and alpha test. the stencil test
        // ensures all pixels are turned "on" in the stencil buffer,
        // and the alpha test ensures we ignore transparent pixels
        glEnable(GL_STENCIL_TEST);
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glDepthMask(GL_FALSE);
        glStencilFunc(GL_NEVER, 1, 0xFF);
        glStencilOp(GL_REPLACE, GL_KEEP, GL_KEEP);  // draw 1s on test fail (always)
        glEnable(GL_ALPHA_TEST);
//        glAlphaFunc(GL_NOTEQUAL, 0.0 );
        glAlphaFunc(GL_GREATER, 0.5);
        glStencilMask(0xFF);
        glClear(GL_STENCIL_BUFFER_BIT);  // needs mask=0xFF
        
        
        // these vertices will stretch the stencil texture
        // across the entire size that we're drawing on
        Vertex3D vertices[] = {
            { p1.x, p1.y},
            { p2.x, p2.y},
            { p3.x, p3.y},
            { p4.x, p4.y}
        };
        const GLfloat texCoords[] = {
            0, 1,
            1, 1,
            0, 0,
            1, 0
        };
        // bind our clipping texture, and draw it
        [clipping bind];
        glVertexPointer(2, GL_FLOAT, 0, vertices);
        glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        
        // now setup the next draw operations to respect
        // the new stencil buffer that's setup
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        glDepthMask(GL_TRUE);
        glStencilMask(0x00);
        glStencilFunc(GL_EQUAL, 1, 0xFF);
    }
    
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
    glVertexPointer(2, GL_FLOAT, 0, vertices);
    glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    // cleanup
    if(clippingPath){
        [clipping unbind];
        glDisable(GL_STENCIL_TEST);
        glDisable(GL_ALPHA_TEST);
        glDeleteRenderbuffersOES(1, &stencil_rb);

        // restore bound render buffer
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_STENCIL_ATTACHMENT_OES, GL_RENDERBUFFER_OES, 0);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, currBoundRendBuff);
    }
    
    // unprep our quad drawing texture, and prep back for
    // drawing lines
    [context glEnableClientState:GL_VERTEX_ARRAY];
    [context glEnableClientState:GL_COLOR_ARRAY];
    [context glEnableClientState:GL_POINT_SIZE_ARRAY_OES];
    [context glDisableClientState:GL_TEXTURE_COORD_ARRAY];

    [self unbind];
}

-(void) dealloc{
    @synchronized([JotGLTexture class]){
        totalTextureBytes -= fullByteSize;
    }
	[self deleteAssets];
}

@end
