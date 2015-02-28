//
//  JotGLContext.h
//  JotUI
//
//  Created by Adam Wulf on 9/23/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "JotGLTypes.h"

@class JotGLTexture;

#define printOpenGLError() printOglError(__FILE__, __LINE__)

int printOglError(char *file, int line);

@interface JotGLContext : EAGLContext

@property (assign) BOOL needsFlush;
@property (nonatomic, readonly) NSMutableDictionary* contextProperties;

// runs the block in the currently active context
+(void) runBlock:(void(^)(JotGLContext* context))block;

// pushes this context, runs the block, and pops
-(void) runBlock:(void(^)(void))block;

+(void) validateEmptyContextStack;

+(void) validateContextMatches:(JotGLContext*)context;

-(id) initWithAPI:(EAGLRenderingAPI)api __attribute__((unavailable("Must use initWithAPI:andValidateThreadWith: instead.")));

-(id) initWithAPI:(EAGLRenderingAPI)api sharegroup:(EAGLSharegroup *)sharegroup __attribute__((unavailable("Must use initWithAPI:sharegroup:andValidateThreadWith: instead.")));

-(id) initWithName:(NSString*)name andAPI:(EAGLRenderingAPI)api andValidateThreadWith:(BOOL(^)())_validateThread;

-(id) initWithName:(NSString*)name andAPI:(EAGLRenderingAPI)api sharegroup:(EAGLSharegroup *)sharegroup andValidateThreadWith:(BOOL(^)())_validateThread;

-(void) glColor4f:(GLfloat)red and:(GLfloat)green and:(GLfloat)blue and:(GLfloat) alpha;

-(void) flush;

-(void) finish;

-(void) runBlockAndMaintainCurrentFramebuffer:(void(^)())block;

-(void) prepOpenGLBlendModeForColor:(UIColor*)color;

-(void) glBlendFunc:(GLenum)sfactor and:(GLenum)dfactor;

-(void) drawTriangleStripCount:(GLsizei)count;

-(void) drawPointCount:(GLsizei)count;

-(void) bindFramebuffer:(GLuint)framebufferId;

-(void) unbindFramebuffer;

-(void) assertCheckFramebuffer;

-(void) assertCurrentBoundFramebufferIs:(GLuint)frameBuffer andRenderBufferIs:(GLuint)renderBuffer;

-(void) glDisableDither;
-(void) glEnableTextures;
-(void) glEnableBlend;
-(void) glEnablePointSprites;

-(void) enableVertexArray;
-(void) enableVertexArrayForSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid *)pointer;
-(void) disableVertexArray;

-(void) enableColorArray;
-(void) enableColorArrayForSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid *)pointer;
-(void) disableColorArray;

-(void) enablePointSizeArray;
-(void) enablePointSizeArrayForStride:(GLsizei) stride andPointer:(const GLvoid *)pointer;
-(void) disablePointSizeArray;

-(void) enableTextureCoordArray;
-(void) enableTextureCoordArrayForSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid *)pointer;
-(void) disableTextureCoordArray;

@end
