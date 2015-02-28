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
 * it's also very important to call [context flush] after drawing
 * using this framebuffer, and to rebind the backing texture before
 * drawing with it
 */
@implementation JotGLTextureBackedFrameBuffer{
    __strong JotGLTexture* texture;
}

@synthesize texture;

-(id) initForTexture:(JotGLTexture*)_texture{
    if(self = [super init]){
        [JotGLContext runBlock:^(JotGLContext* context){
            [context runBlockAndMaintainCurrentFramebuffer:^{
                glGenFramebuffersOES(1, &framebufferID);
                texture = _texture;
                if(framebufferID){
                    // generate FBO
                    [context bindFramebuffer:framebufferID];
                    [texture bind];
                    // associate texture with FBO
                    glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, texture.textureID, 0);
                    [texture unbind];
                }
                [context assertCheckFramebuffer];
            }];
        }];
    }
    return self;
}

-(void) bind{
    [texture bind];
    [super bind];
}

-(void) unbind{
    [super unbind];
    [texture unbind];
}

#pragma mark - Dispatch Queues

+(dispatch_queue_t) importExportTextureQueue{
    if(!importExportTextureQueue){
        importExportTextureQueue = dispatch_queue_create("com.milestonemade.looseleaf.importExportTextureQueue", DISPATCH_QUEUE_SERIAL);
    }
    return importExportTextureQueue;
}

-(void) clear{
    JotGLContext* subContext = [[JotGLContext alloc] initWithName:@"JotTextureBackedFBOSubContext" andAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:[JotGLContext currentContext].sharegroup andValidateThreadWith:^BOOL{
        return [JotView isImportExportImageQueue];
    }];
    [subContext runBlock:^{
        // render it to the backing texture
        //
        //
        // something below here is wrong.
        // and/or how this interacts later
        // with other threads
        [texture bind];
        [subContext bindFramebuffer:framebufferID];
        [subContext clear];
        
        [subContext unbindFramebuffer];
        [texture unbind];
    }];
}

-(void) deleteAssets{
    if(framebufferID && ![JotGLContext currentContext]){
        DebugLog(@"nope");
    }
    glDeleteFramebuffersOES(1, &framebufferID);
    framebufferID = 0;
}

-(void) dealloc{
    [self deleteAssets];
}


@end
