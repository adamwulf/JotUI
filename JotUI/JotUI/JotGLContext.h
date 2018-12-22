//
//  JotGLContext.h
//  JotUI
//
//  Created by Adam Wulf on 9/23/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import "JotGLTypes.h"
#import "JotGLProgram.h"


@class JotGLTexture, JotGLPointProgram, JotGLQuadProgram, JotGLColorlessPointProgram, JotGLColoredPointProgram;

#define printOpenGLError() printOglError(__FILE__, __LINE__)

int printOglError(char* file, int line);


@interface JotGLContext : EAGLContext

@property(assign) BOOL needsFlush;
@property(nonatomic, readonly) NSMutableDictionary* contextProperties;

// runs the block in the currently active context
+ (void)runBlock:(void (^)(JotGLContext* context))block;

// pushes this context, runs the block, and pops
- (void)runBlock:(void (^)(void))block;

+ (void)validateEmptyContextStack;

+ (void)validateContextMatches:(JotGLContext*)context;

- (id)initWithAPI:(EAGLRenderingAPI)api __attribute__((unavailable("Must use initWithAPI:andValidateThreadWith: instead.")));

- (id)initWithAPI:(EAGLRenderingAPI)api sharegroup:(EAGLSharegroup*)sharegroup __attribute__((unavailable("Must use initWithAPI:sharegroup:andValidateThreadWith: instead.")));

- (id)initWithName:(NSString*)name andValidateThreadWith:(BOOL (^)(void))_validateThread;

- (id)initWithName:(NSString*)name andSharegroup:(EAGLSharegroup*)sharegroup andValidateThreadWith:(BOOL (^)(void))_validateThread;

#pragma mark - Shaders

- (JotGLColorlessPointProgram*)colorlessPointProgram;

- (JotGLColoredPointProgram*)coloredPointProgram;

- (JotGLQuadProgram*)quadProgram;

- (JotGLQuadProgram*)stencilProgram;

#pragma mark - Context Properties

- (void)flush;

- (void)finish;

- (void)runBlock:(void (^)(void))block
forStenciledPath:(UIBezierPath*)clippingPath
            atP1:(CGPoint)p1
           andP2:(CGPoint)p2
           andP3:(CGPoint)p3
           andP4:(CGPoint)p4
 andClippingSize:(CGSize)clipSize
  withResolution:(CGSize)resolution
 withVertexIndex:(GLuint)vertIndex
 andTextureIndex:(GLuint)texIndex;

- (void)runBlockAndMaintainCurrentFramebuffer:(void (^)(void))block;

- (void)runBlock:(void (^)(void))block withScissorRect:(CGRect)scissorRect;

- (void)prepOpenGLBlendModeForColor:(UIColor*)color;

- (GLuint)generateTextureForSize:(CGSize)size withBytes:(const GLvoid*)bytes;

- (void)bindTexture:(GLuint)textureId;

- (void)unbindTexture;

- (void)deleteTexture:(GLuint)textureId;

- (GLSize)generateFramebuffer:(GLuint*)framebufferID andRenderbuffer:(GLuint*)viewRenderbuffer andDepthRenderBuffer:(GLuint*)depthRenderbuffer forLayer:(CALayer<EAGLDrawable>*)layer;

- (GLuint)generateFramebufferWithTextureBacking:(JotGLTexture*)texture;

- (void)deleteFramebuffer:(GLuint)framebufferID;

- (void)deleteRenderbuffer:(GLuint)viewRenderbuffer;

- (void)glBlendFuncONE;

- (void)glBlendFuncZERO;

- (void)glViewportWithX:(GLint)x y:(GLint)y width:(GLsizei)width height:(GLsizei)height;

- (void)clear;

- (void)drawTriangleStripCount:(GLsizei)count withProgram:(JotGLProgram*)program;

- (void)drawPointCount:(GLsizei)count withProgram:(JotGLProgram*)program;

- (void)readPixelsInto:(GLubyte*)data ofSize:(GLSize)size;

- (void)bindRenderbuffer:(GLuint)renderBufferId;

- (void)unbindRenderbuffer;

- (void)bindFramebuffer:(GLuint)framebufferId;

- (void)unbindFramebuffer;

- (void)assertCheckFramebuffer;

- (void)assertCurrentBoundFramebufferIs:(GLuint)frameBuffer andRenderBufferIs:(GLuint)renderBuffer;

- (BOOL)presentRenderbuffer:(NSUInteger)target NS_UNAVAILABLE;

- (BOOL)presentRenderbuffer;

- (void)glDisableDither;
- (void)glEnableBlend;

- (void)enableVertexArrayAtIndex:(GLuint)index forSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid*)pointer;

- (void)enableColorArrayAtIndex:(GLuint)index forSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid*)pointer;

- (void)enablePointSizeArrayAtIndex:(GLuint)index forStride:(GLsizei)stride andPointer:(const GLvoid*)pointer;

- (void)enableTextureCoordArrayAtIndex:(GLuint)index forSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid*)pointer;


// want these to be private eventually

- (void)glTexParameteriWithPname:(GLenum)pname param:(GLint)param;

@end
