//
//  JotGLTextureBackedFrameBuffer.m
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLTextureBackedFrameBuffer.h"
#import "JotUI.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>


dispatch_queue_t importExportTextureQueue;

@implementation JotGLTextureBackedFrameBuffer{
    __strong JotGLTexture* texture;
    BOOL hasBeenModifiedSinceLoading;
}

@synthesize framebufferID;
@synthesize texture;

-(id) initForTexture:(JotGLTexture*)_texture{
    if(self = [super init]){
        glGenFramebuffersOES(1, &framebufferID);
        texture = _texture;
        if(framebufferID){
            // generate FBO
            glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebufferID);
            // associate texture with FBO
            glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, texture.textureID, 0);
        }
        // check if it worked (probably worth doing :) )
        GLuint status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
        if (status != GL_FRAMEBUFFER_COMPLETE_OES)
        {
            // didn't work
            NSLog(@"failed to create texture frame buffer");
            return nil;
        }
        hasBeenModifiedSinceLoading = NO;
    }
    return self;
}

#pragma mark - Dispatch Queues

+(dispatch_queue_t) importExportTextureQueue{
    if(!importExportTextureQueue){
        importExportTextureQueue = dispatch_queue_create("com.milestonemade.looseleaf.importExportTextureQueue", DISPATCH_QUEUE_SERIAL);
    }
    return importExportTextureQueue;
}


-(void) exportTextureOnComplete:(void(^)(UIImage*) )exportFinishBlock{
    
    CheckMainThread;
    
    if(!exportFinishBlock) return;
    
    if(!hasBeenModifiedSinceLoading){
        dispatch_async([JotGLTextureBackedFrameBuffer importExportTextureQueue], ^{
            @autoreleasepool {
                exportFinishBlock(nil);
            }
        });
    }
    
    // the texture size has the screen scale baked into it,
    // so this is already in the proper pixel size
    CGSize frameSize = texture.pixelSize;

    // bind our framebuffer. the texture is the colorbuffer
    // that we'll be exporting.
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebufferID);
    
    GLint x = 0, y = 0;
    NSInteger dataLength = frameSize.width * frameSize.height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(x, y, frameSize.width, frameSize.height, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    //
    // the rest can be done in Core Graphics in a background thread
    dispatch_async([JotGLTextureBackedFrameBuffer importExportTextureQueue], ^{
        @autoreleasepool {
            // Create a CGImage with the pixel data from OpenGL
            // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
            // otherwise, use kCGImageAlphaPremultipliedLast
            CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
            CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
            CGImageRef iref = CGImageCreate(frameSize.width, frameSize.height, 8, 32, frameSize.width * 4, colorspace,
                                            kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast,
                                            ref, NULL, true, kCGRenderingIntentDefault);
            
            //
            // ok, now we have the pixel data from the OpenGL frame buffer.
            // next we need to setup the image context to composite the
            // background color, background image, and opengl image
            
            // OpenGL ES measures data in PIXELS
            // Create a graphics context with the target size measured in POINTS
            CGContextRef bitmapContext = CGBitmapContextCreate(NULL, frameSize.width, frameSize.height, 8, frameSize.width * 4, colorspace,
                                                               kCGBitmapByteOrderDefault |
                                                               kCGImageAlphaPremultipliedLast);
            
            
            // flip vertical for our drawn content, since OpenGL is opposite core graphics
            CGContextTranslateCTM(bitmapContext, 0, frameSize.height);
            CGContextScaleCTM(bitmapContext, 1.0, -1.0);
            
            //
            // ok, now render our actual content
            CGContextDrawImage(bitmapContext, CGRectMake(0.0, 0.0, frameSize.width, frameSize.height), iref);
            
            // Retrieve the UIImage from the current context
            CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
            UIImage* image = [UIImage imageWithCGImage:cgImage scale:1.0 orientation:UIImageOrientationUp];
            
            // Clean up
            free(data);
            CFRelease(ref);
            CFRelease(colorspace);
            CGImageRelease(iref);
            CGContextRelease(bitmapContext);
            
            exportFinishBlock(image);
            hasBeenModifiedSinceLoading = NO;
            
            CGImageRelease(cgImage);
        }
    });
}

-(void) clear{
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebufferID);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
}

-(void) willRenderToFrameBuffer{
    hasBeenModifiedSinceLoading = YES;
}

-(void) unload{
    glDeleteFramebuffersOES(1, &framebufferID);
    framebufferID = 0;
}

-(void) dealloc{
    [self unload];
}

@end
