//
//  JotGLContext.h
//  JotUI
//
//  Created by Adam Wulf on 9/23/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
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

-(void) runBlock:(void(^)())block1
        andBlock:(void(^)())block2
forStenciledPath:(UIBezierPath*)clippingPath
            atP1:(CGPoint)p1
           andP2:(CGPoint)p2
           andP3:(CGPoint)p3
           andP4:(CGPoint)p4
 andClippingSize:(CGSize)clipSize
  withResolution:(CGSize)resolution;

-(void) runBlockAndMaintainCurrentFramebuffer:(void(^)())block;

-(void) runBlock:(void(^)())block withScissorRect:(CGRect)scissorRect;

-(void) prepOpenGLBlendModeForColor:(UIColor*)color;

-(GLuint) generateTextureForSize:(CGSize)size withBytes:(const GLvoid *)bytes;

-(void) bindTexture:(GLuint)textureId;

-(void) unbindTexture;

-(void) deleteTexture:(GLuint)textureId;

-(GLSize) generateFramebuffer:(GLuint*)framebufferID andRenderbuffer:(GLuint*)viewRenderbuffer andDepthRenderBuffer:(GLuint*)depthRenderbuffer forLayer:(CALayer<EAGLDrawable>*)layer;

-(GLuint) generateFramebufferWithTextureBacking:(JotGLTexture*)texture;

-(void) deleteFramebuffer:(GLuint)framebufferID;

-(void) deleteRenderbuffer:(GLuint)viewRenderbuffer;

-(void) glOrthof:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top zNear:(GLfloat)zNear zFar:(GLfloat)zFar;

-(void) glViewportWithX:(GLint)x y:(GLint)y width:(GLsizei)width  height:(GLsizei)height;

-(void) clear;

-(void) drawTriangleStripCount:(GLsizei)count;

-(void) drawPointCount:(GLsizei)count;

-(void) readPixelsInto:(GLubyte *)data ofSize:(GLSize)size;

-(void) bindRenderbuffer:(GLuint)renderBufferId;

-(void) unbindRenderbuffer;

-(void) bindFramebuffer:(GLuint)framebufferId;

-(void) unbindFramebuffer;

-(void) assertCheckFramebuffer;

-(void) assertCurrentBoundFramebufferIs:(GLuint)frameBuffer andRenderBufferIs:(GLuint)renderBuffer;

-(BOOL) presentRenderbuffer:(NSUInteger)target NS_UNAVAILABLE;

-(BOOL) presentRenderbuffer;

-(void) glMatrixModeModelView;
-(void) glMatrixModeProjection;
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
