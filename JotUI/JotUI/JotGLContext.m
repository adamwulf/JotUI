//
//  JotGLContext.m
//  JotUI
//
//  Created by Adam Wulf on 9/23/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLContext.h"
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
    
    GLuint currentlyBoundFramebuffer;
    
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

-(void) runBlockAndMaintainCurrentFramebuffer:(void(^)())block{
    [self runBlock:^{
        GLint currBoundFrBuff = -1;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_OES, &currBoundFrBuff);
        
        if(currBoundFrBuff != currentlyBoundFramebuffer){
            @throw [NSException exceptionWithName:@"GLCurrentFramebufferException" reason:@"Unexpected current framebufer" userInfo:nil];
        }
        
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

#pragma mark - Generate Assets

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
