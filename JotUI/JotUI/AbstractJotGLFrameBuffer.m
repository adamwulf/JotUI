//
//  AbstractJotGLFrameBuffer.m
//  JotUI
//
//  Created by Adam Wulf on 1/29/15.
//  Copyright (c) 2015 Adonit. All rights reserved.
//

#import "AbstractJotGLFrameBuffer.h"
#import "JotUI.h"

@implementation AbstractJotGLFrameBuffer

-(void) bind{
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebufferID);
}

-(void) unbind{
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, 0);
}

@end
