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

/**
 * this frame buffer will use a texture as it's backing store,
 * so that anything drawn to this frame buffer will show up
 * on the texture that its initialized with.
 *
 * one very important thing is to rebind the texture after it
 * has been drawn to with this frame buffer
 *
 * it's also very important to call glFlush() after drawing
 * using this framebuffer, and to rebind the backing texture before
 * drawing with it
 */
@implementation JotGLTextureBackedFrameBuffer{
    __strong JotGLTexture* texture;
}

@synthesize framebufferID;
@synthesize texture;

-(id) initForTexture:(JotGLTexture*)_texture{
    if(self = [super init]){
        GLint currBoundFrBuff = -1;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_OES, &currBoundFrBuff);

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
            // rebind to the buffer we began with
            glBindFramebufferOES(GL_FRAMEBUFFER_OES, currBoundFrBuff);
            // didn't work
            NSString* str = [NSString stringWithFormat:@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)];
            NSLog(@"%@", str);
            @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:str userInfo:nil];
            return nil;
        }
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, currBoundFrBuff);
    }
    glFinish();
    return self;
}

#pragma mark - Dispatch Queues

+(dispatch_queue_t) importExportTextureQueue{
    if(!importExportTextureQueue){
        importExportTextureQueue = dispatch_queue_create("com.milestonemade.looseleaf.importExportTextureQueue", DISPATCH_QUEUE_SERIAL);
    }
    return importExportTextureQueue;
}

-(void) clear{
    GLint currBoundFrBuff = -1;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING_OES, &currBoundFrBuff);
//
//    glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebufferID);
//    glClearColor(0.0, 0.0, 0.0, 0.0);
//    glClear(GL_COLOR_BUFFER_BIT);
//
//    glBindFramebufferOES(GL_FRAMEBUFFER_OES, currBoundFrBuff);
    glFinish();
    NSLog(@"clear");
}

-(void) unload{
    glDeleteFramebuffersOES(1, &framebufferID);
    framebufferID = 0;
}

-(void) dealloc{
    [self unload];
}


@end
