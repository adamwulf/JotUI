//
//  JotGLContext.m
//  JotUI
//
//  Created by Adam Wulf on 9/15/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLContext.h"
#import "JotUI.h"


@implementation JotGLContext

- (id) initWithAPI:(EAGLRenderingAPI) api{
    if(self = [super initWithAPI:api]){
        // noop
        
    }
    return self;
}


- (id) initWithAPI:(EAGLRenderingAPI) api sharegroup:(EAGLSharegroup*) sharegroup{
    if(self = [super initWithAPI:api sharegroup:sharegroup]){
        // noop
    }
    return self;
}


+(BOOL) setCurrentContext:(EAGLContext *)context{
    EAGLContext* curr = [EAGLContext currentContext];
    if(curr != context){
        glFlush();
        return [EAGLContext setCurrentContext:context];
    }
    return YES;
}



-(void) glMatrixMode:(GLenum) mode{
    [JotGLContext setCurrentContext:self];
    glMatrixMode(mode);
}

-(void) glEnable:(GLenum) cap{
    [JotGLContext setCurrentContext:self];
    glEnable(cap);
}

-(void) glDisable:(GLenum) cap{
    [JotGLContext setCurrentContext:self];
    glDisable(cap);
}

-(void) glBlendFunc:(GLenum)sfactor and:(GLenum)dfactor{
    [JotGLContext setCurrentContext:self];
    glBlendFunc(sfactor, dfactor);
}

-(void) glTexEnvf:(GLenum) target and:(GLenum)pname and:(GLfloat) param{
    [JotGLContext setCurrentContext:self];
    glTexEnvf(target, pname, param);
}

-(void) glDeleteFramebuffersOES:(GLsizei) n and:(const GLuint*)framebuffers{
    [JotGLContext setCurrentContext:self];
    glDeleteFramebuffersOES(n, framebuffers);
}

-(void) glDeleteRenderbuffersOES:(GLsizei) n and:(const GLuint*)renderbuffers{
    [JotGLContext setCurrentContext:self];
    glDeleteRenderbuffersOES(n, renderbuffers);
}

-(void) glGenFramebuffersOES:(GLsizei) n and:(GLuint*)framebuffers{
    [JotGLContext setCurrentContext:self];
    glGenFramebuffersOES(n, framebuffers);
}

-(void) glGenRenderbuffersOES:(GLsizei) n and:(GLuint*)renderbuffers{
    [JotGLContext setCurrentContext:self];
    glGenRenderbuffersOES(n, renderbuffers);
}

-(void) glBindFramebufferOES:(GLenum) target and:(GLuint)framebuffer{
    [JotGLContext setCurrentContext:self];
    glBindFramebufferOES(target, framebuffer);
}


-(void) glBindRenderbufferOES:(GLenum) target and:(GLuint)renderbuffer{
    [JotGLContext setCurrentContext:self];
    glBindRenderbufferOES(target, renderbuffer);
}

- (BOOL)renderbufferStorage:(NSUInteger)target fromDrawable:(id<EAGLDrawable>)drawable{
    [JotGLContext setCurrentContext:self];
    return [super renderbufferStorage:target fromDrawable:drawable];
}

-(void) glFramebufferRenderbufferOES:(GLenum) target and:(GLenum) attachment and:(GLenum)renderbuffertarget and:(GLuint)renderbuffer{
    [JotGLContext setCurrentContext:self];
    glFramebufferRenderbufferOES(target, attachment, renderbuffertarget, renderbuffer);
}

-(void) glGetRenderbufferParameterivOES:(GLenum)target and:(GLenum)pname and:(GLint*)params{
    [JotGLContext setCurrentContext:self];
    glGetRenderbufferParameterivOES(target, pname, params);
}

-(void) glRenderbufferStorageOES:(GLenum)target and:(GLenum)internalformat and:(GLsizei)width and:(GLsizei)height{
    [JotGLContext setCurrentContext:self];
    glRenderbufferStorageOES(target, internalformat, width, height);
}

-(void) glOrthof:(GLfloat)left and:(GLfloat)right and:(GLfloat)bottom and:(GLfloat)top and:(GLfloat)zNear and:(GLfloat)zFar{
    [JotGLContext setCurrentContext:self];
    glOrthof(left, right, bottom, top, zNear, zFar);
    printOpenGLError();
}

-(void) glViewport:(GLint)x and:(GLint)y and:(GLsizei)width and:(GLsizei)height{
    [JotGLContext setCurrentContext:self];
    glViewport(x, y, width, height);
    printOpenGLError();
}

-(GLenum) glCheckFramebufferStatusOES:(GLenum)target{
    return glCheckFramebufferStatusOES(target);
}

-(void) foo{
    
    
}



@end
