//
//  JotGLTextureBackedFrameBuffer.m
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLTextureBackedFrameBuffer.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@implementation JotGLTextureBackedFrameBuffer{
    __strong JotGLTexture* texture;
}

@synthesize framebufferID;

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
        }
    }
    return self;
}

-(void) clear{
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebufferID);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
}


-(void) unload{
    glDeleteFramebuffersOES(1, &framebufferID);
    framebufferID = 0;
}

-(void) dealloc{
    [self unload];
}

@end
