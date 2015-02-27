//
//  JotGLContext.m
//  JotUI
//
//  Created by Adam Wulf on 9/23/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLContext.h"
#import "JotGLContext+Buffers.h"
#import "JotGLTexture.h"
#import "JotUI.h"
#import <UIKit/UIKit.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>


int printOglError(char *file, int line)
{
    
    GLenum glErr;
    int    retCode = 0;
    
    glErr = glGetError();
    if (glErr != GL_NO_ERROR)
    {
        DebugLog(@"glError in file %s @ line %d: %d\n",
                 file, line, glErr);
        retCode = glErr;
    }
    return retCode;
}

/**
 * the goal of this class is to reduce the number of
 * highly redundant and inefficient OpenGL calls
 *
 * I won't try to run all calls through here, but 
 * this class will track state for some calls so that
 * I don't re-call them unless they actually change.
 *
 * it's VERY important to either always or never call
 * the state methods here. If my internal state gets
 * out of sync with the OpenGL state, then some calls
 * might be dropped when they shouldn't be, which will
 * result in unexpected behavior or crashes
 */

typedef enum UndfBOOL{
    NOPE = NO,
    YEP = YES,
    UNKNOWN
} UndfBOOL;

@implementation JotGLContext{
    NSString* name;
    
    CGFloat lastRed;
    CGFloat lastBlue;
    CGFloat lastGreen;
    CGFloat lastAlpha;

    CGFloat lastClearRed;
    CGFloat lastClearBlue;
    CGFloat lastClearGreen;
    CGFloat lastClearAlpha;
    
    UndfBOOL enabled_GL_VERTEX_ARRAY;
    UndfBOOL enabled_GL_COLOR_ARRAY;
    UndfBOOL enabled_GL_POINT_SIZE_ARRAY_OES;
    UndfBOOL enabled_GL_TEXTURE_COORD_ARRAY;
    UndfBOOL enabled_GL_TEXTURE_2D;
    UndfBOOL enabled_GL_BLEND;
    UndfBOOL enabled_GL_DITHER;
    UndfBOOL enabled_GL_POINT_SPRITE_OES;
    UndfBOOL enabled_GL_SCISSOR_TEST;
    UndfBOOL enabled_GL_STENCIL_TEST;
    UndfBOOL enabled_GL_ALPHA_TEST;
    UndfBOOL enabled_glColorMask_red;
    UndfBOOL enabled_glColorMask_green;
    UndfBOOL enabled_glColorMask_blue;
    UndfBOOL enabled_glColorMask_alpha;
    UndfBOOL enabled_GL_DEPTH_MASK;
    
    GLuint stencilMask;
    GLenum stencilFuncFunc;
    GLint stencilFuncRef;
    GLuint stencilFuncMask;
    GLenum stencilOpFail;
    GLenum stencilOpZfail;
    GLenum stencilOpZpass;

    GLenum alphaFuncFunc;
    GLclampf alphaFuncRef;

    BOOL needsFlush;
    
    GLenum blend_sfactor;
    GLenum blend_dfactor;
    
    GLenum matrixMode;
    
    GLuint currentlyBoundFramebuffer;
    GLuint currentlyBoundRenderbuffer;
    
    GLint vertex_pointer_size;
    GLenum vertex_pointer_type;
    GLsizei vertex_pointer_stride;
    GLvoid* vertex_pointer_pointer;
    
    BOOL(^validateThreadBlock)();
    NSRecursiveLock* lock;
    
    NSMutableDictionary* contextProperties;
}

@synthesize contextProperties;

-(BOOL) validateThread{
    return validateThreadBlock();
}

-(NSRecursiveLock*)lock{
    return lock;
}

#pragma mark - Init

-(void) initAllProperties{
    lastRed = -1;
    lastBlue = -1;
    lastGreen = -1;
    lastAlpha = -1;
    lastClearRed = -1;
    lastClearBlue = -1;
    lastClearGreen = -1;
    lastClearAlpha = -1;
    matrixMode = GL_MODELVIEW;
    enabled_GL_VERTEX_ARRAY = UNKNOWN;
    enabled_GL_COLOR_ARRAY = UNKNOWN;
    enabled_GL_POINT_SIZE_ARRAY_OES = UNKNOWN;
    enabled_GL_TEXTURE_COORD_ARRAY = UNKNOWN;
    enabled_GL_TEXTURE_2D = UNKNOWN;
    enabled_GL_BLEND = UNKNOWN;
    enabled_GL_DITHER = UNKNOWN;
    enabled_GL_POINT_SPRITE_OES = UNKNOWN;
    enabled_GL_SCISSOR_TEST = UNKNOWN;
    enabled_GL_STENCIL_TEST = UNKNOWN;
    enabled_GL_ALPHA_TEST = UNKNOWN;
    enabled_glColorMask_red = YEP;
    enabled_glColorMask_green = YEP;
    enabled_glColorMask_blue = YEP;
    enabled_glColorMask_alpha = YEP;
    enabled_GL_DEPTH_MASK = UNKNOWN;
    stencilMask = 0xFF;
    stencilFuncFunc = GL_ALWAYS;
    stencilFuncRef = 0;
    stencilFuncMask = 0xFF;
    stencilOpFail = GL_KEEP;
    stencilOpZfail = GL_KEEP;
    stencilOpZpass = GL_KEEP;
    alphaFuncFunc = GL_ALWAYS;
    alphaFuncRef = 0;
    currentlyBoundFramebuffer = 0;
    lock = [[NSRecursiveLock alloc] init];
    contextProperties = [NSMutableDictionary dictionary];
}

-(id) initWithName:(NSString*)_name andAPI:(EAGLRenderingAPI)api andValidateThreadWith:(BOOL(^)())_validateThreadBlock{
    if(self = [super initWithAPI:api]){
        name = _name;
        validateThreadBlock = _validateThreadBlock;
        [self initAllProperties];
    }
    return self;
}

-(id) initWithName:(NSString*)_name andAPI:(EAGLRenderingAPI)api sharegroup:(EAGLSharegroup *)sharegroup andValidateThreadWith:(BOOL(^)())_validateThreadBlock{
    if(self = [super initWithAPI:api sharegroup:sharegroup]){
        name = _name;
        validateThreadBlock = _validateThreadBlock;
        [self initAllProperties];
    }
    return self;
}

#pragma mark - Run Blocks

+(void) runBlock:(void(^)(JotGLContext* context))block{
    @autoreleasepool {
        JotGLContext* currentContext = (JotGLContext*) [JotGLContext currentContext];
        if(!currentContext || ![currentContext isKindOfClass:[JotGLContext class]]){
            @throw [NSException exceptionWithName:@"OpenGLException" reason:@"could not push GL Context" userInfo:nil];
        }else{
            if([JotGLContext pushCurrentContext:currentContext]){
                @autoreleasepool {
                    block(currentContext);
                }
            }else{
                @throw [NSException exceptionWithName:@"OpenGLException" reason:@"could not push GL Context" userInfo:nil];
            }
            [JotGLContext validateContextMatches:currentContext];
            [JotGLContext popCurrentContext];
        }
    }
}

-(void) runBlock:(void(^)(void))block{
    @autoreleasepool {
        if([JotGLContext pushCurrentContext:self]){
            @autoreleasepool {
                block();
            }
        }else{
            @throw [NSException exceptionWithName:@"OpenGLException" reason:@"could not push GL Context" userInfo:nil];
        }
        [JotGLContext validateContextMatches:self];
        [JotGLContext popCurrentContext];
    }
}

-(void) runBlock:(void(^)())block withScissorRect:(CGRect)scissorRect{
    [self runBlock:^{

        if(!CGRectEqualToRect(scissorRect, CGRectZero)){
            [self glEnableScissorTest];
            glScissor(scissorRect.origin.x, scissorRect.origin.y, scissorRect.size.width, scissorRect.size.height);
        }else{
            // noop for scissors
        }

        block();

        if(!CGRectEqualToRect(scissorRect, CGRectZero)){
            [self glDisableScissorTest];
        }
    }];
}


-(void) runBlockAndMaintainCurrentFramebuffer:(void(^)())block{
    [self runBlock:^{
        GLint currBoundFrBuff = currentlyBoundFramebuffer;
        
        block();
        
        // rebind to the buffer we began with
        // or unbind altogether
        if(currBoundFrBuff){
            [self bindFramebuffer:currBoundFrBuff];
        }else{
            [self unbindFramebuffer];
        }
    }];
}

+(BOOL) setCurrentContext:(JotGLContext *)context{
    if(context && !context.validateThread){ NSAssert(NO, @"context is set on wrong thread"); };
    return [super setCurrentContext:context];
}

+(BOOL) pushCurrentContext:(JotGLContext*)context{
    if(![[context lock] tryLock]){
        DebugLog(@"gotcha");
        [[context lock] lock];
    }
    NSMutableArray* stackOfContexts = [[[NSThread currentThread] threadDictionary] objectForKey:@"stackOfContexts"];
    if(!stackOfContexts){
        if(!stackOfContexts){
            stackOfContexts = [[NSMutableArray alloc] init];
            [[[NSThread currentThread] threadDictionary] setObject:stackOfContexts forKey:@"stackOfContexts"];
        }
    }
    if([stackOfContexts lastObject] != context){
        // only flush if we get a new context on this thread
        [(JotGLContext*)[JotGLContext currentContext] flush];
    }
    [stackOfContexts addObject:context];
    return [JotGLContext setCurrentContext:context];
}

+(BOOL) popCurrentContext{
    NSMutableArray* stackOfContexts = [[[NSThread currentThread] threadDictionary] objectForKey:@"stackOfContexts"];
    if(!stackOfContexts || [stackOfContexts count] == 0){
        @throw [NSException exceptionWithName:@"JotGLContextException" reason:@"Cannot pop a GLContext from empty stack" userInfo:nil];
    }
    JotGLContext* contextThatIsLeaving = [stackOfContexts lastObject];
    [stackOfContexts removeLastObject];
    [contextThatIsLeaving flush];
    [[contextThatIsLeaving lock] unlock];
    JotGLContext* previousContext = [stackOfContexts lastObject];
    return [JotGLContext setCurrentContext:previousContext]; // ok if its nil
}

+(void) validateEmptyContextStack{
    NSMutableArray* stackOfContexts = [[[NSThread currentThread] threadDictionary] objectForKey:@"stackOfContexts"];
    if([stackOfContexts count] != 0){
        @throw [NSException exceptionWithName:@"JotGLContextException" reason:@"JotGLContext stack must be empty" userInfo:nil];
    }
}

+(void) validateContextMatches:(JotGLContext *)context{
    if(context && context != [JotGLContext currentContext]){
        @throw [NSException exceptionWithName:@"JotGLContextException" reason:@"mismatched current context" userInfo:nil];
    }
}

#pragma mark - Flush

-(void) setNeedsFlush:(BOOL)_needsFlush{
    needsFlush = _needsFlush;
}

-(BOOL) needsFlush{
    return needsFlush;
}

-(void) flush{
    needsFlush = NO;
    glFlush();
}
-(void) finish{
    needsFlush = NO;
    glFinish();
}

#pragma mark - Enable Disable State

-(void) glAlphaFunc:(GLenum)func ref:(GLclampf) ref{
    if(alphaFuncFunc != func || alphaFuncRef != ref){
        alphaFuncFunc = func;
        alphaFuncRef = ref;
        glAlphaFunc(func, ref);
    }
}

-(void) glStencilOp:(GLenum)fail zfail:(GLenum)zfail zpass:(GLenum)zpass{
    if(stencilOpFail != fail || stencilOpZfail != zfail || stencilOpZpass != zpass){
        stencilOpFail = fail;
        stencilOpZfail = zfail;
        stencilOpZpass = zpass;
        glStencilOp(fail, zfail, zpass);
    }
}

-(void) glStencilFunc:(GLenum)func ref:(GLint)ref mask:(GLuint) mask{
    if(stencilFuncFunc != func || stencilFuncRef != ref || stencilFuncMask != mask){
        stencilFuncFunc = func;
        stencilFuncRef = ref;
        stencilFuncMask = mask;
        glStencilFunc(func, ref, mask);
    }
}

-(void) glStencilMask:(GLuint)mask{
    if(mask != stencilMask){
        glStencilMask(mask);
        stencilMask = mask;
    }
}

-(void) glDisableDepthMask{
    if(enabled_GL_DEPTH_MASK == YEP || enabled_GL_DEPTH_MASK == UNKNOWN){
        glDepthMask(GL_FALSE);
        enabled_GL_DEPTH_MASK = NOPE;
    }
}

-(void) glEnableDepthMask{
    if(enabled_GL_DEPTH_MASK == NOPE || enabled_GL_DEPTH_MASK == UNKNOWN){
        glDepthMask(GL_TRUE);
        enabled_GL_DEPTH_MASK = YEP;
    }
}

-(void) glColorMaskRed:(GLboolean)red green:(GLboolean)green blue:(GLboolean)blue alpha:(GLboolean)alpha{
    if(red != enabled_glColorMask_red || green != enabled_glColorMask_green || blue != enabled_glColorMask_blue || alpha != enabled_glColorMask_alpha){
        glColorMask(red, green, blue, alpha);
        enabled_glColorMask_red = red ? YEP : NOPE;
        enabled_glColorMask_green = green ? YEP : NOPE;
        enabled_glColorMask_blue = blue ? YEP : NOPE;
        enabled_glColorMask_alpha = alpha ? YEP : NOPE;
    }
}

-(void) glDisableAlphaTest{
    if(enabled_GL_ALPHA_TEST == YEP || enabled_GL_ALPHA_TEST == UNKNOWN){
        glDisable(GL_ALPHA_TEST);
        enabled_GL_ALPHA_TEST = NOPE;
    }
}

-(void) glEnableAlphaTest{
    if(enabled_GL_ALPHA_TEST == NOPE || enabled_GL_ALPHA_TEST == UNKNOWN){
        glEnable(GL_ALPHA_TEST);
        enabled_GL_ALPHA_TEST = YEP;
    }
}

-(void) glDisableStencilTest{
    if(enabled_GL_STENCIL_TEST == YEP || enabled_GL_STENCIL_TEST == UNKNOWN){
        glDisable(GL_STENCIL_TEST);
        enabled_GL_STENCIL_TEST = NOPE;
    }
}

-(void) glEnableStencilTest{
    if(enabled_GL_STENCIL_TEST == NOPE || enabled_GL_STENCIL_TEST == UNKNOWN){
        glEnable(GL_STENCIL_TEST);
        enabled_GL_STENCIL_TEST = YEP;
    }
}

-(void) glDisableScissorTest{
    if(enabled_GL_SCISSOR_TEST == YEP || enabled_GL_SCISSOR_TEST == UNKNOWN){
        glDisable(GL_SCISSOR_TEST);
        enabled_GL_SCISSOR_TEST = NOPE;
    }
}

-(void) glEnableScissorTest{
    if(enabled_GL_SCISSOR_TEST == NOPE || enabled_GL_SCISSOR_TEST == UNKNOWN){
        glEnable(GL_SCISSOR_TEST);
        enabled_GL_SCISSOR_TEST = YEP;
    }
}

-(void) glDisableDither{
    if(enabled_GL_DITHER == YEP || enabled_GL_DITHER == UNKNOWN){
        glDisable(GL_DITHER);
        enabled_GL_DITHER = NOPE;
    }
}

-(void) glEnableTextures{
    if(enabled_GL_TEXTURE_2D == NOPE || enabled_GL_TEXTURE_2D == UNKNOWN){
        glEnable(GL_TEXTURE_2D);
        enabled_GL_TEXTURE_2D = YEP;
    }
}

-(void) glEnableBlend{
    if(enabled_GL_BLEND == NOPE || enabled_GL_BLEND == UNKNOWN){
        glEnable(GL_BLEND);
        enabled_GL_BLEND = YEP;
    }
}

-(void) glEnablePointSprites{
    if(enabled_GL_POINT_SPRITE_OES == NOPE || enabled_GL_POINT_SPRITE_OES == UNKNOWN){
        glEnable(GL_POINT_SPRITE_OES);
        glTexEnvf(GL_POINT_SPRITE_OES, GL_COORD_REPLACE_OES, GL_TRUE);
        enabled_GL_POINT_SPRITE_OES = YEP;
    }
}

-(void) glMatrixModeModelView{
    [self glMatrixMode:GL_MODELVIEW];
}

-(void) glMatrixModeProjection{
    [self glMatrixMode:GL_PROJECTION];
}

-(void) glMatrixMode:(GLenum)mode{
    if(matrixMode != mode){
        glMatrixMode(mode);
        matrixMode = mode;
    }
}

-(void) enableVertexArray{
    [self glEnableClientState:GL_VERTEX_ARRAY];
}
-(void) enableVertexArrayForSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid *)pointer{
    [self glEnableClientState:GL_VERTEX_ARRAY];
    glVertexPointer(size, GL_FLOAT, stride, pointer);
}
-(void) disableVertexArray{
    [self glDisableClientState:GL_VERTEX_ARRAY];
}

-(void) enableColorArray{
    [self glEnableClientState:GL_COLOR_ARRAY];
}
-(void) enableColorArrayForSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid *)pointer{
    [self glEnableClientState:GL_COLOR_ARRAY];
    glColorPointer(size, GL_FLOAT, stride, pointer);
}
-(void) disableColorArray{
    [self glDisableClientState:GL_COLOR_ARRAY];
}

-(void) enablePointSizeArray{
    [self glEnableClientState:GL_POINT_SIZE_ARRAY_OES];
}
-(void) enablePointSizeArrayForStride:(GLsizei) stride andPointer:(const GLvoid *)pointer{
    [self glEnableClientState:GL_POINT_SIZE_ARRAY_OES];
    glPointSizePointerOES(GL_FLOAT, stride, pointer);
}
-(void) disablePointSizeArray{
    [self glDisableClientState:GL_POINT_SIZE_ARRAY_OES];
}

-(void) enableTextureCoordArray{
    [self glEnableClientState:GL_TEXTURE_COORD_ARRAY];
}
-(void) enableTextureCoordArrayForSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid *)pointer{
    [self glEnableClientState:GL_TEXTURE_COORD_ARRAY];
    glTexCoordPointer(size, GL_FLOAT, stride, pointer);
    
}
-(void) disableTextureCoordArray{
    [self glDisableClientState:GL_TEXTURE_COORD_ARRAY];
}

-(void) glEnableClientState:(GLenum)array{
    if(array == GL_VERTEX_ARRAY){
        if(enabled_GL_VERTEX_ARRAY == NOPE || enabled_GL_VERTEX_ARRAY == UNKNOWN){
            enabled_GL_VERTEX_ARRAY = YES;
            glEnableClientState(array);
        }
    }else if(array == GL_COLOR_ARRAY){
        if(enabled_GL_COLOR_ARRAY == NOPE || enabled_GL_COLOR_ARRAY == UNKNOWN){
            enabled_GL_COLOR_ARRAY = YES;
            glEnableClientState(array);
            lastAlpha = -1; // need to reset glColor4f http://lwjgl.org/forum/index.php?topic=2424.0
            [self glColor4f:lastRed and:lastGreen and:lastBlue and:lastAlpha];
        }
    }else if(array == GL_POINT_SIZE_ARRAY_OES){
        if(enabled_GL_POINT_SIZE_ARRAY_OES == NOPE || enabled_GL_POINT_SIZE_ARRAY_OES == UNKNOWN){
            enabled_GL_POINT_SIZE_ARRAY_OES = YES;
            glEnableClientState(array);
        }
    }else if(array == GL_TEXTURE_COORD_ARRAY){
        if(enabled_GL_TEXTURE_COORD_ARRAY == NOPE || enabled_GL_TEXTURE_COORD_ARRAY == UNKNOWN){
            enabled_GL_TEXTURE_COORD_ARRAY = YES;
            glEnableClientState(array);
        }
    }else{
        @throw [NSException exceptionWithName:@"GLStateException" reason:@"Unknown state" userInfo:nil];
    }
}
    
-(void) glDisableClientState:(GLenum)array{
    if(array == GL_VERTEX_ARRAY){
        if(enabled_GL_VERTEX_ARRAY == YEP || enabled_GL_VERTEX_ARRAY == UNKNOWN){
            enabled_GL_VERTEX_ARRAY = NOPE;
            glDisableClientState(array);
        }
    }else if(array == GL_COLOR_ARRAY){
        if(enabled_GL_COLOR_ARRAY == YEP || enabled_GL_COLOR_ARRAY == UNKNOWN){
            enabled_GL_COLOR_ARRAY = NOPE;
            glDisableClientState(array);
            lastAlpha = -1; // need to reset glColor4f http://lwjgl.org/forum/index.php?topic=2424.0
            [self glColor4f:lastRed and:lastGreen and:lastBlue and:lastAlpha];
        }
    }else if(array == GL_POINT_SIZE_ARRAY_OES){
        if(enabled_GL_POINT_SIZE_ARRAY_OES == YEP || enabled_GL_POINT_SIZE_ARRAY_OES == UNKNOWN){
            enabled_GL_POINT_SIZE_ARRAY_OES = NOPE;
            glDisableClientState(array);
        }
    }else if(array == GL_TEXTURE_COORD_ARRAY){
        if(enabled_GL_TEXTURE_COORD_ARRAY == YEP || enabled_GL_TEXTURE_COORD_ARRAY == UNKNOWN){
            enabled_GL_TEXTURE_COORD_ARRAY = NOPE;
            glDisableClientState(array);
        }
    }else{
        @throw [NSException exceptionWithName:@"GLStateException" reason:@"Unknown state" userInfo:nil];
    }
}

#pragma mark - Stencil

-(void) runBlock:(void(^)())block1
        andBlock:(void(^)())block2
forStenciledPath:(UIBezierPath*)clippingPath
            atP1:(CGPoint)p1
           andP2:(CGPoint)p2
           andP3:(CGPoint)p3
           andP4:(CGPoint)p4
 andClippingSize:(CGSize)clipSize
  withResolution:(CGSize)resolution{
    [self runBlock:^{
        
        JotGLTexture* clipping;
        GLuint stencil_rb;
        
        if(clippingPath){

            CGSize pathSize = clippingPath.bounds.size;
            pathSize.width = ceilf(pathSize.width);
            pathSize.height = ceilf(pathSize.height);
            
            // on high res screens, the input path is in
            // pt instead of px, so we need to make sure
            // the clipping texture is in the same coordinate
            // space as the gl context. to do that build
            // a texture that matches the path's bounds, and
            // it'll stretch to fill the context.
            //
            // https://github.com/adamwulf/loose-leaf/issues/408
            //
            // generate simple coregraphics texture in coregraphics
            UIGraphicsBeginImageContextWithOptions(clipSize, NO, 1);
            CGContextRef cgContext = UIGraphicsGetCurrentContext();
            CGContextClearRect(cgContext, CGRectMake(0, 0, clipSize.width, clipSize.height));
            [[UIColor whiteColor] setFill];
            [clippingPath fill];
            CGContextSetBlendMode(cgContext, kCGBlendModeClear);
            CGContextSetBlendMode(cgContext, kCGBlendModeNormal);
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            // this is an image that's filled white with our path and
            // clear everywhere else
            clipping = [[JotGLTexture alloc] initForImage:image withSize:image.size];
        }
        
        //
        // run block 1
        block1();
        GLint currBoundRendBuff = currentlyBoundRenderbuffer;
        
        if(clippingPath){
            
            //
            // prep our context to draw our texture as a quad.
            // now prep to draw the actual texture
            // always draw
            
            // if we were provided a clippingPath, then we should
            // use it as our stencil when drawing our texture
            
            // always draw to stencil with correct blend mode
            [self glBlendFunc:GL_ONE and:GL_ONE_MINUS_SRC_ALPHA];
            
            // setup stencil buffers
            glGenRenderbuffersOES(1, &stencil_rb);
            //        DebugLog(@"new renderbuffer: %d", stencil_rb);
            [self bindRenderbuffer:stencil_rb];
            glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_STENCIL_INDEX8_OES, resolution.width, resolution.height);
            glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_STENCIL_ATTACHMENT_OES, GL_RENDERBUFFER_OES, stencil_rb);
            
            [self assertCheckFramebuffer];
            
            // setup the stencil test and alpha test. the stencil test
            // ensures all pixels are turned "on" in the stencil buffer,
            // and the alpha test ensures we ignore transparent pixels
            [self glEnableStencilTest];
            [self glColorMaskRed:GL_FALSE green:GL_FALSE blue:GL_FALSE alpha:GL_FALSE];
            [self glDisableDepthMask];
            [self glStencilFunc:GL_NEVER ref:1 mask:0xFF];
            [self glStencilOp:GL_REPLACE zfail:GL_KEEP zpass:GL_KEEP];  // draw 1s on test fail (always)
            [self glEnableAlphaTest];
            [self glAlphaFunc:GL_GREATER ref:0.5];
            [self glStencilMask:0xFF];
            glClear(GL_STENCIL_BUFFER_BIT);  // needs mask=0xFF
            
            
            // these vertices will stretch the stencil texture
            // across the entire size that we're drawing on
            Vertex3D vertices[] = {
                { p1.x, p1.y},
                { p2.x, p2.y},
                { p3.x, p3.y},
                { p4.x, p4.y}
            };
            const GLfloat texCoords[] = {
                0, 1,
                1, 1,
                0, 0,
                1, 0
            };
            // bind our clipping texture, and draw it
            [clipping bind];
            
            [self disableColorArray];
            [self disablePointSizeArray];
            [self glColor4f:1 and:1 and:1 and:1];
            
            [self enableVertexArrayForSize:2 andStride:0 andPointer:vertices];
            [self enableTextureCoordArrayForSize:2 andStride:0 andPointer:texCoords];
            [self drawTriangleStripCount:4];
            
            
            // now setup the next draw operations to respect
            // the new stencil buffer that's setup
            [self glColorMaskRed:GL_TRUE green:GL_TRUE blue:GL_TRUE alpha:GL_TRUE];
            [self glEnableDepthMask];
            [self glStencilMask:0x00];
            [self glStencilFunc:GL_EQUAL ref:1 mask:0xFF];
        }
        
        ////////////////////////////
        // stencil is setup
        block2();
        //
        
        
        if(clippingPath){
            ////////////////////////////
            // turn stencil off
            //
            [clipping unbind];
            [self glDisableStencilTest];
            [self glDisableAlphaTest];
            [self unbindRenderbuffer];
            glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_STENCIL_ATTACHMENT_OES, GL_RENDERBUFFER_OES, 0);
            [self deleteRenderbuffer:stencil_rb];
            
            
            // restore bound render buffer
            if(currBoundRendBuff){
                [self bindRenderbuffer:currBoundRendBuff];
            }else{
                [self unbindRenderbuffer];
            }
        }
    }];
}

#pragma mark - Color and Blend Mode

-(void) glClearColor:(GLfloat)red and:(GLfloat)green and:(GLfloat)blue and:(GLfloat) alpha{
    if(red != lastClearRed || green != lastClearGreen || blue != lastClearBlue || alpha != lastClearAlpha){
        glClearColor(red, green, blue, alpha);
        lastClearRed = red;
        lastClearGreen = green;
        lastClearBlue = blue;
        lastClearAlpha = alpha;
    }
}

-(void) glColor4f:(GLfloat)red and:(GLfloat)green and:(GLfloat)blue and:(GLfloat) alpha{
    if(red != lastRed || green != lastGreen || blue != lastBlue || alpha != lastAlpha){
        glColor4f(red, green, blue, alpha);
        lastRed = red;
        lastGreen = green;
        lastBlue = blue;
        lastAlpha = alpha;
    }
}

-(void) prepOpenGLBlendModeForColor:(UIColor*)color{
    if(!color){
        // eraser
        [self glBlendFunc:GL_ZERO and:GL_ONE_MINUS_SRC_ALPHA];
    }else{
        // normal brush
        [self glBlendFunc:GL_ONE and:GL_ONE_MINUS_SRC_ALPHA];
    }
}

-(void) glBlendFunc:(GLenum)sfactor and:(GLenum)dfactor{
    if(blend_sfactor != sfactor ||
       blend_dfactor != dfactor){
        blend_sfactor = sfactor;
        blend_dfactor = dfactor;
        glBlendFunc(blend_sfactor, blend_dfactor);
    }
}

-(void) glOrthof:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top zNear:(GLfloat)zNear zFar:(GLfloat)zFar{
    glOrthof(left, right, bottom, top, zNear, zFar);
}

-(void) glViewportWithX:(GLint)x y:(GLint)y width:(GLsizei)width  height:(GLsizei)height{
    glViewport(x, y, width, height);
}

-(void) clear{
    [self glClearColor:0 and:0 and:0 and:0];
    glClear(GL_COLOR_BUFFER_BIT);
}

-(void) drawTriangleStripCount:(GLsizei)count{
    if(!enabled_GL_TEXTURE_COORD_ARRAY || enabled_GL_POINT_SIZE_ARRAY_OES || enabled_GL_COLOR_ARRAY || !enabled_GL_VERTEX_ARRAY){
        @throw [NSException exceptionWithName:@"GLDrawTriangleException" reason:@"bad state" userInfo:nil];
    }
    glDrawArrays(GL_TRIANGLE_STRIP, 0, count);
}

-(void) drawPointCount:(GLsizei)count{
    if(enabled_GL_TEXTURE_COORD_ARRAY || !enabled_GL_POINT_SIZE_ARRAY_OES || !enabled_GL_VERTEX_ARRAY){
        // enabled_GL_COLOR_ARRAY is optional for point drawing
        @throw [NSException exceptionWithName:@"GLDrawPointException" reason:@"bad state" userInfo:nil];
    }
    glDrawArrays(GL_POINTS, 0, count);
}

-(void) readPixelsInto:(GLubyte *)data ofSize:(GLSize)size{
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(0, 0, size.width, size.height, GL_RGBA, GL_UNSIGNED_BYTE, data);
}

#pragma mark - Generate Assets

-(GLuint) generateTextureForSize:(CGSize)size withBytes:(const GLvoid *)bytes{
    GLuint canvastexture;
    glGenTextures(1, &canvastexture);
    glBindTexture(GL_TEXTURE_2D, canvastexture);
    
    //
    // http://stackoverflow.com/questions/5835656/glframebuffertexture2d-fails-on-iphone-for-certain-texture-sizes
    // these are required for non power of 2 textures on iPad 1 version of OpenGL1.1
    // otherwise, the glCheckFramebufferStatusOES will be GL_FRAMEBUFFER_UNSUPPORTED_OES
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,  size.width, size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, bytes);
    
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return canvastexture;
}

-(void) bindTexture:(GLuint)textureId{
    glBindTexture(GL_TEXTURE_2D, textureId);
}

-(void) unbindTexture{
    glBindTexture(GL_TEXTURE_2D, 0);
}

-(void) deleteTexture:(GLuint)textureId{
    glDeleteTextures(1, &textureId);
}

-(GLuint) generateFramebufferWithTextureBacking:(JotGLTexture *)texture{
    __block GLuint framebufferID;
    [self runBlockAndMaintainCurrentFramebuffer:^{
        glGenFramebuffersOES(1, &framebufferID);
        if(framebufferID){
            // generate FBO
            [self bindFramebuffer:framebufferID];
            [texture bind];
            // associate texture with FBO
            glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, texture.textureID, 0);
            [texture unbind];
        }
        [self assertCheckFramebuffer];
    }];
    
    return framebufferID;
}

-(GLSize) generateFramebuffer:(GLuint*)framebufferID
              andRenderbuffer:(GLuint*)viewRenderbuffer
         andDepthRenderBuffer:(GLuint*)depthRenderbuffer
                     forLayer:(CALayer<EAGLDrawable>*)layer{
    
    GLint backingWidth, backingHeight;
    
    // Generate IDs for a framebuffer object and a color renderbuffer
    glGenFramebuffersOES(1, framebufferID);
    glGenRenderbuffersOES(1, viewRenderbuffer);
    
    [self bindFramebuffer:framebufferID[0]];
    [self bindRenderbuffer:viewRenderbuffer[0]];
    // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
    // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
    [self renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:layer];
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, *viewRenderbuffer);
    
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    
    // For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
    glGenRenderbuffersOES(1, depthRenderbuffer);
    [self bindRenderbuffer:depthRenderbuffer[0]];
    glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, *depthRenderbuffer);
    
    return GLSizeMake(backingWidth, backingHeight);
}

-(void) bindFramebuffer:(GLuint)framebuffer{
    if(framebuffer && currentlyBoundFramebuffer != framebuffer){
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebuffer);
        currentlyBoundFramebuffer = framebuffer;
    }else if(!framebuffer){
        @throw [NSException exceptionWithName:@"GLBindFramebufferExcpetion" reason:@"Trying to bind nil framebuffer" userInfo:nil];
    }
}
-(void) unbindFramebuffer{
    if(currentlyBoundFramebuffer != 0){
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, 0);
        currentlyBoundFramebuffer = 0;
    }
}

-(void) deleteFramebuffer:(GLuint)framebufferID{
    if(currentlyBoundFramebuffer == framebufferID){
        @throw [NSException exceptionWithName:@"GLDeleteBoundBufferException" reason:@"deleting currently boudn buffer" userInfo:nil];
    }
    glDeleteFramebuffersOES(1, &framebufferID);
}

-(void) deleteRenderbuffer:(GLuint)viewRenderbuffer{
    if(currentlyBoundRenderbuffer == viewRenderbuffer){
        @throw [NSException exceptionWithName:@"GLDeleteBoundBufferException" reason:@"deleting currently boudn buffer" userInfo:nil];
    }
    glDeleteRenderbuffersOES(1, &viewRenderbuffer);
}

-(void) bindRenderbuffer:(GLuint)renderBufferId{
    if(renderBufferId && currentlyBoundRenderbuffer != renderBufferId){
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, renderBufferId);
        currentlyBoundRenderbuffer = renderBufferId;
    }else if(!renderBufferId){
        @throw [NSException exceptionWithName:@"GLBindRenderbufferExceptoin" reason:@"trying to bind nil renderbuffer" userInfo:nil];
    }
}

-(void) unbindRenderbuffer{
    if(currentlyBoundRenderbuffer){
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, 0);
        currentlyBoundRenderbuffer = 0;
    }
}

-(BOOL) presentRenderbuffer{
    return [super presentRenderbuffer:GL_RENDERBUFFER_OES];
}

#pragma mark - Assert

-(void) assertCheckFramebuffer{
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
    {
        NSString* str = [NSString stringWithFormat:@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)];
        DebugLog(@"%@", str);
        @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:str userInfo:nil];
    }
}

-(void) assertCurrentBoundFramebufferIs:(GLuint)framebufferID andRenderBufferIs:(GLuint)viewRenderbuffer{
    GLint currBoundFrBuff = -1;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING_OES, &currBoundFrBuff);
    GLint currBoundRendBuff = -1;
    glGetIntegerv(GL_RENDERBUFFER_BINDING_OES, &currBoundRendBuff);
    if(currBoundFrBuff != framebufferID){
        @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:[NSString stringWithFormat:@"Expected %d but was %d", framebufferID, currBoundFrBuff] userInfo:nil];
    }
    if(currBoundRendBuff != viewRenderbuffer){
        @throw [NSException exceptionWithName:@"Renderbuffer Exception" reason:[NSString stringWithFormat:@"Expected %d but was %d", viewRenderbuffer, currBoundRendBuff] userInfo:nil];
    }
}

#pragma mark - Buffers

static NSInteger zeroedCacheNumber = -1;
static void * zeroedDataCache = nil;

-(GLuint) generateArrayBufferForSize:(GLsizeiptr)mallocSize forCacheNumber:(NSInteger)cacheNumber{
    GLuint vbo;
    // zeroedDataCache is a pointer to zero'd memory that we
    // use to initialze our VBO. This prevents "VBO uses uninitialized data"
    // warning in Instruments, and will only waste a few Kb of memory
    if(cacheNumber > zeroedCacheNumber){
        @synchronized([JotGLContext class]){
            if(zeroedDataCache){
                free(zeroedDataCache);
            }
            zeroedCacheNumber = cacheNumber;
            zeroedDataCache = calloc(cacheNumber, kJotBufferBucketSize);
            if(!zeroedDataCache){
                @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't calloc" userInfo:nil];
            }
        }
    }
    // generate the VBO in OpenGL
    glGenBuffers(1,&vbo);
    glBindBuffer(GL_ARRAY_BUFFER,vbo);
    @synchronized([JotGLContext class]){
        // initialize the buffer to zero'd data
        glBufferData(GL_ARRAY_BUFFER, mallocSize, zeroedDataCache, GL_DYNAMIC_DRAW);
    }
    // unbind after alloc
    glBindBuffer(GL_ARRAY_BUFFER,0);
    return vbo;
}

-(void) bindArrayBuffer:(GLuint)buffer{
    glBindBuffer(GL_ARRAY_BUFFER,buffer);
}

-(void) updateArrayBufferWithBytes:(const GLvoid *)bytes atOffset:(GLintptr)offset andLength:(GLsizeiptr)len{
    glBufferSubData(GL_ARRAY_BUFFER, offset, len, bytes);
}

-(void) unbindArrayBuffer{
    glBindBuffer(GL_ARRAY_BUFFER,0);
}

-(void) deleteBuffer:(GLuint)buffer{
    glDeleteBuffers(1,&buffer);
}

#pragma mark - Dealloc

-(void) dealloc{
    [self runBlock:^{
        [contextProperties removeAllObjects];
    }];
}

-(NSString*) description{
    return [NSString stringWithFormat:@"[JotGLContext (%p): %@]", self, name];
}

@end
