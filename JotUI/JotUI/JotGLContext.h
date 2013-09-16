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

-(void) glGenTextures:(GLsizei)n and:(GLuint*)textures;

-(void) glBindTexture:(GLenum)target and:(GLuint)texture;

-(void) glTexParameteri:(GLenum)target and:(GLenum)pname and:(GLint)param;

-(void) glTexImage2D:(GLenum)target and:(GLint)level and:(GLint)internalformat and:(GLsizei)width
                 and:(GLsizei)height and:(GLint)border and:(GLenum)format and:(GLenum)type and:(const GLvoid *)pixels;

-(void) glFramebufferTexture2DOES:(GLenum)target and:(GLenum)attachment and:(GLenum)textarget and:(GLuint)texture and:(GLint)level;

-(void) glTexParameterf:(GLenum)target and:(GLenum)pname and:(GLfloat)param;

-(void) glClearColor:(GLclampf)red and:(GLclampf)green and:(GLclampf)blue and:(GLclampf)alpha;

-(void) glClear:(GLbitfield)mask;

-(void) glPixelStorei:(GLenum)pname and:(GLint)param;

-(void) glReadPixels:(GLint)x and:(GLint)y and:(GLsizei)width and:(GLsizei)height and:(GLenum)format and:(GLenum)type and:(GLvoid*)pixels;

-(void) glDeleteTextures:(GLsizei)n and:(const GLuint*)textures;

-(void) glScissor:(GLint)x and:(GLint)y and:(GLsizei)width and:(GLsizei)height;

-(void) glEnableClientState:(GLenum)array;

-(void) glDisableClientState:(GLenum)array;

-(void) glBindBuffer:(GLenum)target and:(GLuint)buffer;

-(void) glVertexPointer:(GLint)size and:(GLenum)type and:(GLsizei)stride and:(const GLvoid*)pointer;

-(void) glColorPointer:(GLint)size and:(GLenum)type and:(GLsizei)stride and:(const GLvoid*)pointer;

-(void) glPointSizePointerOES:(GLenum)type and:(GLsizei)stride and:(const GLvoid*)pointer;

-(void) glColor4f:(GLfloat)red and:(GLfloat)green and:(GLfloat)blue and:(GLfloat)alpha;

@end
