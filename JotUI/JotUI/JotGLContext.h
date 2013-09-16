//
//  JotGLContext.h
//  JotUI
//
//  Created by Adam Wulf on 9/15/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@interface JotGLContext : EAGLContext

-(void) glMatrixMode:(GLenum) mode;

-(void) glEnable:(GLenum) cap;

-(void) glDisable:(GLenum) cap;

-(void) glBlendFunc:(GLenum)sfactor and:(GLenum)dfactor;

-(void) glTexEnvf:(GLenum) target and:(GLenum)pname and:(GLfloat) param;

-(void) glDeleteFramebuffersOES:(GLsizei) n and:(const GLuint*)framebuffers;

-(void) glDeleteRenderbuffersOES:(GLsizei) n and:(const GLuint*)renderbuffers;

-(void) glGenFramebuffersOES:(GLsizei) n and:(GLuint*)framebuffers;

-(void) glGenRenderbuffersOES:(GLsizei) n and:(GLuint*)renderbuffers;

-(void) glBindFramebufferOES:(GLenum) target and:(GLuint)framebuffer;

-(void) glBindRenderbufferOES:(GLenum) target and:(GLuint)renderbuffer;

- (BOOL)renderbufferStorage:(NSUInteger)target fromDrawable:(id<EAGLDrawable>)drawable;

-(void) glFramebufferRenderbufferOES:(GLenum) target and:(GLenum) attachment and:(GLenum)renderbuffertarget and:(GLuint)renderbuffer;

-(void) glGetRenderbufferParameterivOES:(GLenum)target and:(GLenum)pname and:(GLint*)params;

-(void) glRenderbufferStorageOES:(GLenum)target and:(GLenum)internalformat and:(GLsizei)width and:(GLsizei)height;

-(void) glOrthof:(GLfloat)left and:(GLfloat)right and:(GLfloat)bottom and:(GLfloat)top and:(GLfloat)zNear and:(GLfloat)zFar;

-(void) glViewport:(GLint)x and:(GLint)y and:(GLsizei)width and:(GLsizei)height;

-(GLenum) glCheckFramebufferStatusOES:(GLenum)target;

@end
