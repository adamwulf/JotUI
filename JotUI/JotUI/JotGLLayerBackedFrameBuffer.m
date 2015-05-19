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
            
            [context generateFramebuffer:&framebufferID andRenderbuffer:&viewRenderbuffer andDepthRenderBuffer:&depthRenderbuffer forLayer:layer];
            
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

-(void) bind{
    [super bind];
    [JotGLContext runBlock:^(JotGLContext * context) {
        [context bindRenderbuffer:viewRenderbuffer];
    }];
}

-(void) unbind{
    [super unbind];
    [JotGLContext runBlock:^(JotGLContext * context) {
        [context unbindRenderbuffer];
    }];
}

-(void) setNeedsPresentRenderBuffer{
    needsPresentRenderBuffer = YES;
}

-(void) presentRenderBufferInContext:(JotGLContext*)context{
    [context runBlock:^{
        if(needsPresentRenderBuffer && (!shouldslow || slowtoggle)){
            [self bind];
            //        NSLog(@"presenting");
            [context assertCurrentBoundFramebufferIs:framebufferID andRenderBufferIs:viewRenderbuffer];
            [context assertCheckFramebuffer];

            [context presentRenderbuffer];

            needsPresentRenderBuffer = NO;
            [self unbind];
        }
        slowtoggle = !slowtoggle;
        if([context needsFlush]){
            [context flush];
        }
    }];
}

-(void) clear{
    [JotGLContext runBlock:^(JotGLContext*context){
        [self bind];
        //
        // something below here is wrong.
        // and/or how this interacts later
        // with other threads (?)
        [context clear];
        
        [self unbind];
    }];
}

-(void) deleteAssets{
    [JotGLContext runBlock:^(JotGLContext * context) {
        if(framebufferID){
            [context deleteFramebuffer:framebufferID];
            framebufferID = 0;
        }
        if(viewRenderbuffer){
            [context deleteRenderbuffer:viewRenderbuffer];
            viewRenderbuffer = 0;
        }
        if(depthRenderbuffer){
            [context deleteRenderbuffer:depthRenderbuffer];
            depthRenderbuffer = 0;
        }
    }];
}

-(void) dealloc{
    NSAssert([JotTrashManager isTrashManagerQueue], @"must be on trash queue");
    [self deleteAssets];
}

@end
