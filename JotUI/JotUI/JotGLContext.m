//
//  JotGLContext.m
//  JotUI
//
//  Created by Adam Wulf on 9/15/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLContext.h"
#import "JotUI.h"

#define kGL_COLOR_ARRAY 0
#define kGL_NORMAL_ARRAY 1
#define kGL_POINT_SIZE_ARRAY_OES 2
#define kGL_TEXTURE_COORD_ARRAY 3
#define kGL_VERTEX_ARRAY 4
#define kGL_ARRAY_BUFFER 0
#define kGL_ELEMENT_ARRAY_BUFFER 1

@implementation JotGLContext{
    // glEnableClientState
    BOOL clientStateEnabled[5];
    // glColor4f
    GLfloat lastRed, lastGreen, lastBlue, lastAlpha;
    // glBindBuffer
    GLuint lastBoundBuffer[2];
    //glVertexPointer
    GLint lastVertextPointerSize;
    GLenum lastVertextPointerType;
    GLsizei lastVertextPointerStride;
    GLvoid* lastVertextPointerPointer;
    // blend func
    GLenum lastsfactor, lastdfactor;
}

- (id) initWithAPI:(EAGLRenderingAPI) api{
    if(self = [super initWithAPI:api]){
        [self initIvars];
    }
    return self;
}


- (id) initWithAPI:(EAGLRenderingAPI) api sharegroup:(EAGLSharegroup*) sharegroup{
    if(self = [super initWithAPI:api sharegroup:sharegroup]){
        [self initIvars];
    }
    return self;
}

-(void) initIvars{
    clientStateEnabled[0] = NO;
    clientStateEnabled[1] = NO;
    clientStateEnabled[2] = NO;
    clientStateEnabled[3] = NO;
    clientStateEnabled[4] = NO;
    
    lastRed = -1, lastGreen = -1, lastBlue = -1, lastAlpha = -1;
    lastBoundBuffer[0] = 0;
    lastBoundBuffer[1] = 0;
    lastVertextPointerSize = 0;
    lastVertextPointerType = 0;
    lastVertextPointerStride = 0;
    lastVertextPointerPointer = nil;
    lastsfactor = -1;
    lastdfactor = -1;
}


+(BOOL) setCurrentContext:(EAGLContext *)context{
    EAGLContext* curr = [EAGLContext currentContext];
    if(curr != context){
        glFlush();
        if([context isKindOfClass:[JotGLContext class]]){
            [(JotGLContext*)context flushed];
        }
        return [EAGLContext setCurrentContext:context];
    }
    return YES;
}

-(void) flushed{
    [self initIvars];
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
//    if(lastsfactor != sfactor || lastdfactor != dfactor){
//        glBlendFunc(sfactor, dfactor);
//        lastsfactor = sfactor;
//        lastdfactor = dfactor;
//    }
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
//    if(array == GL_COLOR_ARRAY && !clientStateEnabled[kGL_COLOR_ARRAY]){
//        clientStateEnabled[kGL_COLOR_ARRAY] = YES;
//        glEnableClientState(array);
//    }else if(array == GL_POINT_SIZE_ARRAY_OES && !clientStateEnabled[kGL_POINT_SIZE_ARRAY_OES]){
//        clientStateEnabled[kGL_POINT_SIZE_ARRAY_OES] = YES;
//        glEnableClientState(array);
//    }else if(array == GL_NORMAL_ARRAY && !clientStateEnabled[kGL_NORMAL_ARRAY]){
//        clientStateEnabled[kGL_NORMAL_ARRAY] = YES;
//        glEnableClientState(array);
//    }else if(array == GL_TEXTURE_COORD_ARRAY && !clientStateEnabled[kGL_TEXTURE_COORD_ARRAY]){
//        clientStateEnabled[kGL_TEXTURE_COORD_ARRAY] = YES;
//        glEnableClientState(array);
//    }else if(array == GL_VERTEX_ARRAY && !clientStateEnabled[kGL_VERTEX_ARRAY]){
//        clientStateEnabled[kGL_VERTEX_ARRAY] = YES;
//        glEnableClientState(array);
//    }
    glEnableClientState(array);
}

-(void) glDisableClientState:(GLenum)array{
    [JotGLContext setCurrentContext:self];
//    if(array == GL_COLOR_ARRAY && clientStateEnabled[kGL_COLOR_ARRAY]){
//        clientStateEnabled[kGL_COLOR_ARRAY] = NO;
//        glDisableClientState(array);
//    }else if(array == GL_POINT_SIZE_ARRAY_OES && clientStateEnabled[kGL_POINT_SIZE_ARRAY_OES]){
//        clientStateEnabled[kGL_POINT_SIZE_ARRAY_OES] = NO;
//        glDisableClientState(array);
//    }else if(array == GL_NORMAL_ARRAY && clientStateEnabled[kGL_NORMAL_ARRAY]){
//        clientStateEnabled[kGL_NORMAL_ARRAY] = NO;
//        glDisableClientState(array);
//    }else if(array == GL_TEXTURE_COORD_ARRAY && clientStateEnabled[kGL_TEXTURE_COORD_ARRAY]){
//        clientStateEnabled[kGL_TEXTURE_COORD_ARRAY] = NO;
//        glDisableClientState(array);
//    }else if(array == GL_VERTEX_ARRAY && clientStateEnabled[kGL_VERTEX_ARRAY]){
//        clientStateEnabled[kGL_VERTEX_ARRAY] = NO;
//        glDisableClientState(array);
//    }
    glDisableClientState(array);
}

-(void) glBindBuffer:(GLenum)target and:(GLuint)buffer{
    [JotGLContext setCurrentContext:self];
    glBindBuffer(target, buffer);
//    if(target == GL_ARRAY_BUFFER && buffer != lastBoundBuffer[kGL_ARRAY_BUFFER]){
//        glBindBuffer(target, buffer);
//        lastBoundBuffer[kGL_ARRAY_BUFFER] = buffer;
//    }else if(target == GL_ELEMENT_ARRAY_BUFFER && buffer != lastBoundBuffer[kGL_ELEMENT_ARRAY_BUFFER]){
//        glBindBuffer(target, buffer);
//        lastBoundBuffer[kGL_ELEMENT_ARRAY_BUFFER] = buffer;
//    }
}

-(void) glVertexPointer:(GLint)size and:(GLenum)type and:(GLsizei)stride and:(const GLvoid*)pointer{
    [JotGLContext setCurrentContext:self];
//    if(size != lastVertextPointerSize ||
//       type != lastVertextPointerType ||
//       stride != lastVertextPointerStride ||
//       pointer != lastVertextPointerPointer){
//        glVertexPointer(size, type, stride, pointer);
//        lastVertextPointerSize = size;
//        lastVertextPointerType = type;
//        lastVertextPointerStride = stride;
//        lastVertextPointerPointer = (GLvoid*) pointer;
//    }
    glVertexPointer(size, type, stride, pointer);
}

-(void) glColorPointer:(GLint)size and:(GLenum)type and:(GLsizei)stride and:(const GLvoid*)pointer{
    [JotGLContext setCurrentContext:self];
    glColorPointer(size, type, stride, pointer);
}

-(void) glPointSizePointerOES:(GLenum)type and:(GLsizei)stride and:(const GLvoid*)pointer{
    [JotGLContext setCurrentContext:self];
    glPointSizePointerOES(type, stride, pointer);
}

-(void) glColor4f:(GLfloat)red and:(GLfloat)green and:(GLfloat)blue and:(GLfloat)alpha{
    [JotGLContext setCurrentContext:self];
    if(red != lastRed || green != lastGreen || blue != lastBlue || alpha != lastAlpha){
        glColor4f(red, green, blue, alpha);
        lastRed = red;
        lastGreen = green;
        lastBlue = blue;
        lastAlpha = alpha;
    }
}

@end
