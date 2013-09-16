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

-(void) glGenTextures:(GLsizei)n and:(GLuint*)textures{
    [JotGLContext setCurrentContext:self];
    glGenTextures(n, textures);
}

-(void) glBindTexture:(GLenum)target and:(GLuint)texture{
    [JotGLContext setCurrentContext:self];
    glBindTexture(target, texture);
}

-(void) glTexParameteri:(GLenum)target and:(GLenum)pname and:(GLint)param{
    [JotGLContext setCurrentContext:self];
    glTexParameteri(target, pname, param);
}

-(void) glTexImage2D:(GLenum)target and:(GLint)level and:(GLint)internalformat and:(GLsizei)width
                 and:(GLsizei)height and:(GLint)border and:(GLenum)format and:(GLenum)type and:(const GLvoid *)pixels{
    [JotGLContext setCurrentContext:self];
    glTexImage2D(target, level, internalformat, width, height, border, format, type, pixels);
}

-(void) glFramebufferTexture2DOES:(GLenum)target and:(GLenum)attachment and:(GLenum)textarget and:(GLuint)texture and:(GLint)level{
    [JotGLContext setCurrentContext:self];
    glFramebufferTexture2DOES(target, attachment, textarget, texture, level);
}

-(void) glTexParameterf:(GLenum)target and:(GLenum)pname and:(GLfloat)param{
    [JotGLContext setCurrentContext:self];
    glTexParameterf(target, pname, param);
}

-(void) glClearColor:(GLclampf)red and:(GLclampf)green and:(GLclampf)blue and:(GLclampf)alpha{
    [JotGLContext setCurrentContext:self];
    glClearColor(red, green, blue, alpha);
}

-(void) glClear:(GLbitfield)mask{
    [JotGLContext setCurrentContext:self];
    glClear(mask);
}

-(void) glPixelStorei:(GLenum)pname and:(GLint)param{
    [JotGLContext setCurrentContext:self];
    glPixelStorei(pname, param);
}

-(void) glReadPixels:(GLint)x and:(GLint)y and:(GLsizei)width and:(GLsizei)height and:(GLenum)format and:(GLenum)type and:(GLvoid*)pixels{
    [JotGLContext setCurrentContext:self];
    glReadPixels(x, y, width, height, format, type, pixels);
}

-(void) glDeleteTextures:(GLsizei)n and:(const GLuint*)textures{
    [JotGLContext setCurrentContext:self];
    glDeleteTextures(n, textures);
}

-(void) glScissor:(GLint)x and:(GLint)y and:(GLsizei)width and:(GLsizei)height{
    [JotGLContext setCurrentContext:self];
    glScissor(x, y, width, height);
}

-(void) glEnableClientState:(GLenum)array{
    [JotGLContext setCurrentContext:self];
    glEnableClientState(array);
}

-(void) glDisableClientState:(GLenum)array{
    [JotGLContext setCurrentContext:self];
    glDisableClientState(array);
}

@end
