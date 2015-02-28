//
//  JotGLRenderBackedFrameBuffer.m
//  JotUI
//
//  Created by Adam Wulf on 1/29/15.
//  Copyright (c) 2015 Adonit. All rights reserved.
//

#import "JotGLLayerBackedFrameBuffer.h"
#import "JotView.h"

@implementation JotGLLayerBackedFrameBuffer{
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    GLuint viewRenderbuffer;
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    GLuint depthRenderbuffer;

    CGSize initialViewport;
    
    CALayer<EAGLDrawable>* layer;
    
    // YES if we need to present our renderbuffer on the
    // next display link
    BOOL needsPresentRenderBuffer;
    // YES if we should limit to 30fps, NO otherwise
    BOOL shouldslow;
    // helper var to toggle between frames for 30fps limit
    BOOL slowtoggle;
}

@synthesize initialViewport;
@synthesize shouldslow;

-(id) initForLayer:(CALayer<EAGLDrawable>*)_layer{
    if(self = [super init]){
        CheckMainThread;
        layer = _layer;
        [JotGLContext runBlock:^(JotGLContext* context){
            // The pixel dimensions of the backbuffer
            GLint backingWidth;
            GLint backingHeight;
            
            // Generate IDs for a framebuffer object and a color renderbuffer
            glGenFramebuffersOES(1, &framebufferID);
            glGenRenderbuffersOES(1, &viewRenderbuffer);
            
            [context bindFramebuffer:framebufferID];
            [context bindRenderbuffer:viewRenderbuffer];
            // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
            // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
            [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:layer];
            glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
            
            glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
            glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
            
            // For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
            glGenRenderbuffersOES(1, &depthRenderbuffer);
            [context bindRenderbuffer:depthRenderbuffer];
            glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
            glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
            
            CGRect frame = layer.bounds;
            CGFloat scale = layer.contentsScale;
            
            initialViewport = CGSizeMake(frame.size.width * scale, frame.size.height * scale);
            
            [context glOrthof:0 right:(GLsizei) initialViewport.width bottom:0 top:(GLsizei) initialViewport.height zNear:-1 zFar:1];
            [context glViewportWithX:0 y:0 width:(GLsizei) initialViewport.width height:(GLsizei) initialViewport.height];
            
            [context assertCheckFramebuffer];
            
            [context bindRenderbuffer:viewRenderbuffer];
            
            [self clear];
        }];
    }
    return self;
}

-(void) setNeedsPresentRenderBuffer{
    needsPresentRenderBuffer = YES;
}

-(void) presentRenderBufferInContext:(JotGLContext*)context{
    [context runBlock:^{
        if(needsPresentRenderBuffer && (!shouldslow || slowtoggle)){
            [self bind];
            
            [context assertCurrentBoundFramebufferIs:framebufferID andRenderBufferIs:viewRenderbuffer];
            
            [context bindRenderbuffer:viewRenderbuffer];
            [context assertCheckFramebuffer];

            [context presentRenderbuffer];

            needsPresentRenderBuffer = NO;
            [self unbind];
        }
        slowtoggle = !slowtoggle;
        if([context needsFlush]){
//        NSLog(@"flush");
            [context flush];
        }
    }];
}

-(void) clear{
    [JotGLContext runBlock:^(JotGLContext*context){
        //
        // something below here is wrong.
        // and/or how this interacts later
        // with other threads
        [context bindFramebuffer:framebufferID];
        [context clear];
        [context unbindFramebuffer];
    }];
}

-(void) deleteAssets{
    if(framebufferID){
        glDeleteFramebuffersOES(1, &framebufferID);
        framebufferID = 0;
    }
    if(viewRenderbuffer){
        glDeleteRenderbuffersOES(1, &viewRenderbuffer);
        viewRenderbuffer = 0;
    }
    if(depthRenderbuffer){
        glDeleteRenderbuffersOES(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
}

-(void) dealloc{
    [self deleteAssets];
}

@end
