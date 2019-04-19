//
//  JotGLContext.m
//  JotUI
//
//  Created by Adam Wulf on 9/23/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import "JotGLContext.h"
#import "JotUI.h"
#import <UIKit/UIKit.h>
#import <OpenGLES/EAGLDrawable.h>
#import <GLKit/GLKit.h>
#import <mach/mach_time.h> // for mach_absolute_time() and friends
#import "JotGLLayerBackedFrameBuffer.h"
#import "JotGLTextureBackedFrameBuffer+Private.h"
#import "JotGLTexture+Private.h"
#import "JotGLQuadProgram.h"
#import "JotGLPointProgram.h"
#import "JotGLColorlessPointProgram.h"
#import "JotGLColoredPointProgram.h"

int printOglError(char* file, int line) {
    GLenum glErr;
    int retCode = 0;

    glErr = glGetError();
    if (glErr != GL_NO_ERROR) {
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

typedef enum UndfBOOL {
    NOPE = NO,
    YEP = YES,
    UNKNOWN
} UndfBOOL;


@implementation JotGLContext {
    NSString* name;

    JotGLColoredPointProgram* coloredPointProgram;
    JotGLColorlessPointProgram* colorlessPointProgram;
    JotGLQuadProgram* quadProgram;
    JotGLQuadProgram* stencilProgram;

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
    const GLvoid* vertex_pointer_pointer;

    GLint color_pointer_size;
    GLenum color_pointer_type;
    GLsizei color_pointer_stride;
    const GLvoid* color_pointer_pointer;

    GLenum point_pointer_type;
    GLsizei point_pointer_stride;
    const GLvoid* point_pointer_pointer;

    GLint texcoord_pointer_size;
    GLenum texcoord_pointer_type;
    GLsizei texcoord_pointer_stride;
    const GLvoid* texcoord_pointer_pointer;

    GLfloat ortho_left;
    GLfloat ortho_right;
    GLfloat ortho_top;
    GLfloat ortho_bottom;
    GLfloat ortho_znear;
    GLfloat ortho_zfar;

    GLint viewport_x;
    GLint viewport_y;
    GLsizei viewport_width;
    GLsizei viewport_height;

    GLint texparam_GL_TEXTURE_MIN_FILTER;
    GLint texparam_GL_TEXTURE_MAG_FILTER;
    GLint texparam_GL_TEXTURE_WRAP_S;
    GLint texparam_GL_TEXTURE_WRAP_T;

    BOOL (^validateThreadBlock)(void);
    NSRecursiveLock* lock;

    NSMutableDictionary* contextProperties;
}

@synthesize contextProperties;

- (BOOL)validateThread {
    return validateThreadBlock();
}

- (NSRecursiveLock*)lock {
    return lock;
}

#pragma mark - Init

- (void)initAllProperties {
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
    currentlyBoundRenderbuffer = 0;
    vertex_pointer_size = 0;
    vertex_pointer_type = 0;
    vertex_pointer_stride = 0;
    vertex_pointer_pointer = NULL;
    color_pointer_size = 0;
    color_pointer_type = 0;
    color_pointer_stride = 0;
    color_pointer_pointer = NULL;
    point_pointer_type = 0;
    point_pointer_stride = 0;
    point_pointer_pointer = NULL;
    texcoord_pointer_size = 0;
    texcoord_pointer_type = 0;
    texcoord_pointer_stride = 0;
    ortho_left = 0;
    ortho_right = 0;
    ortho_top = 0;
    ortho_bottom = 0;
    ortho_znear = 0;
    ortho_zfar = 0;
    viewport_x = 0;
    viewport_y = 0;
    viewport_width = 0;
    viewport_height = 0;
    texcoord_pointer_pointer = NULL;
    texparam_GL_TEXTURE_MIN_FILTER = 0;
    texparam_GL_TEXTURE_MAG_FILTER = 0;
    texparam_GL_TEXTURE_WRAP_S = 0;
    texparam_GL_TEXTURE_WRAP_T = 0;
    lock = [[NSRecursiveLock alloc] init];
    contextProperties = [NSMutableDictionary dictionary];
}

- (id)initWithName:(NSString*)_name andValidateThreadWith:(BOOL (^)(void))_validateThreadBlock {
    if (self = [super initWithAPI:kEAGLRenderingAPIOpenGLES2]) {
        name = _name;
        validateThreadBlock = _validateThreadBlock;
        [self initAllProperties];
    }
    return self;
}

- (id)initWithName:(NSString*)_name andSharegroup:(EAGLSharegroup*)sharegroup andValidateThreadWith:(BOOL (^)(void))_validateThreadBlock {
    if (self = [super initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:sharegroup]) {
        name = _name;
        validateThreadBlock = _validateThreadBlock;
        [self initAllProperties];
    }
    return self;
}

#pragma mark - Shaders

- (JotGLColorlessPointProgram*)colorlessPointProgram {
    if (!colorlessPointProgram) {
        [self runBlock:^{
            colorlessPointProgram = [[JotGLColorlessPointProgram alloc] init];
        }];
    }
    return colorlessPointProgram;
}

- (JotGLColoredPointProgram*)coloredPointProgram {
    if (!coloredPointProgram) {
        [self runBlock:^{
            coloredPointProgram = [[JotGLColoredPointProgram alloc] init];
        }];
    }
    return coloredPointProgram;
}

- (JotGLQuadProgram*)quadProgram {
    if (!quadProgram) {
        [self runBlock:^{
            quadProgram = [[JotGLQuadProgram alloc] initWithVertexShaderFilename:@"quad"
                                                          fragmentShaderFilename:@"quad"];
        }];
    }
    return quadProgram;
}

- (JotGLQuadProgram*)stencilProgram {
    if (!stencilProgram) {
        [self runBlock:^{
            stencilProgram = [[JotGLQuadProgram alloc] initWithVertexShaderFilename:@"quad"
                                                             fragmentShaderFilename:@"stencil"];
        }];
    }
    return stencilProgram;
}


#pragma mark - Run Blocks

+ (void)runBlock:(void (^)(JotGLContext* context))block {
    @autoreleasepool {
        JotGLContext* currentContext = (JotGLContext*)[JotGLContext currentContext];
        if (!currentContext) {
            @throw [NSException exceptionWithName:@"OpenGLException" reason:@"cannot run block without GL Context" userInfo:nil];
        } else if (![currentContext isKindOfClass:[JotGLContext class]]) {
            @throw [NSException exceptionWithName:@"OpenGLException" reason:@"currentContext must be a JotGLContext" userInfo:nil];
        } else {
            if ([JotGLContext pushCurrentContext:currentContext]) {
                @autoreleasepool {
                    printOpenGLError();
                    block(currentContext);
                    printOpenGLError();
                }
            } else {
                @throw [NSException exceptionWithName:@"OpenGLException" reason:@"+could not push GL Context" userInfo:nil];
            }
            [JotGLContext validateContextMatches:currentContext];
            [JotGLContext popCurrentContext];
        }
    }
}

- (void)runBlock:(void (^)(void))block {
    @autoreleasepool {
        if ([JotGLContext pushCurrentContext:self]) {
            @autoreleasepool {
                printOpenGLError();
                block();
                printOpenGLError();
            }
        } else {
            @throw [NSException exceptionWithName:@"OpenGLException" reason:@"-could not push GL Context" userInfo:nil];
        }
        [JotGLContext validateContextMatches:self];
        [JotGLContext popCurrentContext];
    }
}

- (void)runBlock:(void (^)(void))block withScissorRect:(CGRect)scissorRect {
    [self runBlock:^{

        if (!CGRectEqualToRect(scissorRect, CGRectZero)) {
            [self glEnableScissorTest];
            glScissor(scissorRect.origin.x, scissorRect.origin.y, scissorRect.size.width, scissorRect.size.height);
        } else {
            // noop for scissors
        }

        printOpenGLError();
        block();
        printOpenGLError();

        if (!CGRectEqualToRect(scissorRect, CGRectZero)) {
            [self glDisableScissorTest];
        }
    }];
}


- (void)runBlockAndMaintainCurrentFramebuffer:(void (^)(void))block {
    [self runBlock:^{
        GLint currBoundFrBuff = -1;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &currBoundFrBuff);

        if (currBoundFrBuff != currentlyBoundFramebuffer) {
            @throw [NSException exceptionWithName:@"GLCurrentFramebufferException" reason:@"Unexpected current framebufer" userInfo:nil];
        }

        printOpenGLError();
        block();
        printOpenGLError();

        // rebind to the buffer we began with
        // or unbind altogether
        if (currBoundFrBuff) {
            [self bindFramebuffer:currBoundFrBuff];
        } else {
            [self unbindFramebuffer];
        }
    }];
}

+ (BOOL)setCurrentContext:(JotGLContext*)context {
    if (context && !context.validateThread) {
        NSAssert(NO, @"context is set on wrong thread");
    };
    return [super setCurrentContext:context];
}

+ (BOOL)pushCurrentContext:(JotGLContext*)context {
    if (!context) {
        @throw [NSException exceptionWithName:@"OpenGLException" reason:@"cannot push nil context" userInfo:nil];
    }
    if (![[context lock] tryLock]) {
        [[context lock] lock];
    }
    NSMutableArray* stackOfContexts = [[[NSThread currentThread] threadDictionary] objectForKey:@"stackOfContexts"];
    if (!stackOfContexts) {
        if (!stackOfContexts) {
            stackOfContexts = [[NSMutableArray alloc] init];
            [[[NSThread currentThread] threadDictionary] setObject:stackOfContexts forKey:@"stackOfContexts"];
        }
    }
    if ([stackOfContexts lastObject] != context) {
        // only flush if we get a new context on this thread
        [(JotGLContext*)[stackOfContexts lastObject] flush];
    }
    [stackOfContexts addObject:context];
    return [JotGLContext setCurrentContext:context];
}

+ (BOOL)popCurrentContext {
    NSMutableArray* stackOfContexts = [[[NSThread currentThread] threadDictionary] objectForKey:@"stackOfContexts"];
    if (!stackOfContexts || [stackOfContexts count] == 0) {
        @throw [NSException exceptionWithName:@"JotGLContextException" reason:@"Cannot pop a GLContext from empty stack" userInfo:nil];
    }
    JotGLContext* contextThatIsLeaving = [stackOfContexts lastObject];
    [stackOfContexts removeLastObject];
    [contextThatIsLeaving flush];
    [[contextThatIsLeaving lock] unlock];
    JotGLContext* previousContext = [stackOfContexts lastObject];
    return [JotGLContext setCurrentContext:previousContext]; // ok if its nil
}

+ (void)validateEmptyContextStack {
    NSMutableArray* stackOfContexts = [[[NSThread currentThread] threadDictionary] objectForKey:@"stackOfContexts"];
    if ([stackOfContexts count] != 0) {
        @throw [NSException exceptionWithName:@"JotGLContextException" reason:@"JotGLContext stack must be empty" userInfo:nil];
    }
}

+ (void)validateContextMatches:(JotGLContext*)context {
    if (context && context != [JotGLContext currentContext]) {
        @throw [NSException exceptionWithName:@"JotGLContextException" reason:@"mismatched current context" userInfo:nil];
    }
}

- (void)validateCurrentContext {
#ifdef DEBUG
#define ValidateCurrentContext [JotGLContext validateContextMatches:self];
#else
#define ValidateCurrentContext
#endif
}

#pragma mark - Flush

- (void)setNeedsFlush:(BOOL)_needsFlush {
    ValidateCurrentContext;
    [self validateCurrentContext];
    needsFlush = _needsFlush;
}

- (BOOL)needsFlush {
    ValidateCurrentContext;
    return needsFlush;
}

- (void)flush {
    ValidateCurrentContext;
    needsFlush = NO;
    glFlush();
}
- (void)finish {
    ValidateCurrentContext;
    needsFlush = NO;
    glFinish();
}

#pragma mark - Enable Disable State

- (void)glStencilOp:(GLenum)fail zfail:(GLenum)zfail zpass:(GLenum)zpass {
    ValidateCurrentContext;
    if (stencilOpFail != fail || stencilOpZfail != zfail || stencilOpZpass != zpass) {
        stencilOpFail = fail;
        stencilOpZfail = zfail;
        stencilOpZpass = zpass;
        glStencilOp(fail, zfail, zpass);
    }
    printOpenGLError();
}

- (void)glStencilFunc:(GLenum)func ref:(GLint)ref mask:(GLuint)mask {
    ValidateCurrentContext;
    if (stencilFuncFunc != func || stencilFuncRef != ref || stencilFuncMask != mask) {
        stencilFuncFunc = func;
        stencilFuncRef = ref;
        stencilFuncMask = mask;
        glStencilFunc(func, ref, mask);
    }
    printOpenGLError();
}

- (void)glStencilMask:(GLuint)mask {
    ValidateCurrentContext;
    if (mask != stencilMask) {
        glStencilMask(mask);
        stencilMask = mask;
    }
    printOpenGLError();
}

- (void)glDisableDepthMask {
    ValidateCurrentContext;
    if (enabled_GL_DEPTH_MASK == YEP || enabled_GL_DEPTH_MASK == UNKNOWN) {
        glDepthMask(GL_FALSE);
        enabled_GL_DEPTH_MASK = NOPE;
    }
    printOpenGLError();
}

- (void)glEnableDepthMask {
    ValidateCurrentContext;
    if (enabled_GL_DEPTH_MASK == NOPE || enabled_GL_DEPTH_MASK == UNKNOWN) {
        glDepthMask(GL_TRUE);
        enabled_GL_DEPTH_MASK = YEP;
    }
    printOpenGLError();
}

- (void)glColorMaskRed:(GLboolean)red green:(GLboolean)green blue:(GLboolean)blue alpha:(GLboolean)alpha {
    ValidateCurrentContext;
    if (red != enabled_glColorMask_red || green != enabled_glColorMask_green || blue != enabled_glColorMask_blue || alpha != enabled_glColorMask_alpha) {
        glColorMask(red, green, blue, alpha);
        enabled_glColorMask_red = red ? YEP : NOPE;
        enabled_glColorMask_green = green ? YEP : NOPE;
        enabled_glColorMask_blue = blue ? YEP : NOPE;
        enabled_glColorMask_alpha = alpha ? YEP : NOPE;
    }
    printOpenGLError();
}

- (void)glDisableStencilTest {
    ValidateCurrentContext;
    if (enabled_GL_STENCIL_TEST == YEP || enabled_GL_STENCIL_TEST == UNKNOWN) {
        glDisable(GL_STENCIL_TEST);
        enabled_GL_STENCIL_TEST = NOPE;
    }
    printOpenGLError();
}

- (void)glEnableStencilTest {
    ValidateCurrentContext;
    if (enabled_GL_STENCIL_TEST == NOPE || enabled_GL_STENCIL_TEST == UNKNOWN) {
        glEnable(GL_STENCIL_TEST);
        enabled_GL_STENCIL_TEST = YEP;
    }
    printOpenGLError();
}

- (void)glDisableScissorTest {
    ValidateCurrentContext;
    if (enabled_GL_SCISSOR_TEST == YEP || enabled_GL_SCISSOR_TEST == UNKNOWN) {
        glDisable(GL_SCISSOR_TEST);
        enabled_GL_SCISSOR_TEST = NOPE;
    }
    printOpenGLError();
}

- (void)glEnableScissorTest {
    ValidateCurrentContext;
    if (enabled_GL_SCISSOR_TEST == NOPE || enabled_GL_SCISSOR_TEST == UNKNOWN) {
        glEnable(GL_SCISSOR_TEST);
        enabled_GL_SCISSOR_TEST = YEP;
    }
    printOpenGLError();
}

- (void)glDisableDither {
    ValidateCurrentContext;
    if (enabled_GL_DITHER == YEP || enabled_GL_DITHER == UNKNOWN) {
        glDisable(GL_DITHER);
        enabled_GL_DITHER = NOPE;
    }
    printOpenGLError();
}

- (void)glEnableBlend {
    ValidateCurrentContext;
    if (enabled_GL_BLEND == NOPE || enabled_GL_BLEND == UNKNOWN) {
        glEnable(GL_BLEND);
        enabled_GL_BLEND = YEP;
    }
    printOpenGLError();
}

- (void)enableVertexArrayAtIndex:(GLuint)index forSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid*)pointer {
    glEnableVertexAttribArray(index);
    printOpenGLError();
    glVertexAttribPointer(index, size, GL_FLOAT, GL_FALSE, stride, pointer);
    vertex_pointer_size = size;
    vertex_pointer_type = GL_FLOAT;
    vertex_pointer_stride = stride;
    vertex_pointer_pointer = pointer;
    printOpenGLError();
}

- (void)enableColorArrayAtIndex:(GLuint)index forSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid*)pointer {
    glEnableVertexAttribArray(index);
    printOpenGLError();
    glVertexAttribPointer(index, size, GL_FLOAT, GL_FALSE, stride, pointer);
    color_pointer_size = size;
    color_pointer_type = GL_FLOAT;
    color_pointer_stride = stride;
    color_pointer_pointer = pointer;
    printOpenGLError();
}

- (void)enablePointSizeArrayAtIndex:(GLuint)index forStride:(GLsizei)stride andPointer:(const GLvoid*)pointer {
    glEnableVertexAttribArray(index);
    printOpenGLError();
    glVertexAttribPointer(index, 1, GL_FLOAT, GL_FALSE, stride, pointer);
    point_pointer_type = GL_FLOAT;
    point_pointer_stride = stride;
    point_pointer_pointer = pointer;
    printOpenGLError();
}

- (void)enableTextureCoordArrayAtIndex:(GLuint)index forSize:(GLint)size andStride:(GLsizei)stride andPointer:(const GLvoid*)pointer {
    glEnableVertexAttribArray(index);
    glVertexAttribPointer(index, size, GL_FLOAT, GL_FALSE, stride, pointer);
    texcoord_pointer_size = size;
    texcoord_pointer_type = GL_FLOAT;
    texcoord_pointer_stride = stride;
    texcoord_pointer_pointer = pointer;
    printOpenGLError();
}


- (void)glTexParameteriWithPname:(GLenum)pname param:(GLint)param {
    if (pname == GL_TEXTURE_MIN_FILTER) {
        texparam_GL_TEXTURE_MIN_FILTER = param;
        glTexParameteri(GL_TEXTURE_2D, pname, param);
    } else if (pname == GL_TEXTURE_MAG_FILTER) {
        texparam_GL_TEXTURE_MAG_FILTER = param;
        glTexParameteri(GL_TEXTURE_2D, pname, param);
    } else if (pname == GL_TEXTURE_WRAP_S) {
        texparam_GL_TEXTURE_WRAP_S = param;
        glTexParameteri(GL_TEXTURE_2D, pname, param);
    } else if (pname == GL_TEXTURE_WRAP_T) {
        texparam_GL_TEXTURE_WRAP_T = param;
        glTexParameteri(GL_TEXTURE_2D, pname, param);
    } else {
        @throw [NSException exceptionWithName:@"TextureParamException" reason:@"Unknown texture parameter" userInfo:nil];
    }
    printOpenGLError();
}

#pragma mark - Stencil

- (void)runBlock:(void (^)(void))block
forStenciledPath:(UIBezierPath*)clippingPath
            atP1:(CGPoint)p1
           andP2:(CGPoint)p2
           andP3:(CGPoint)p3
           andP4:(CGPoint)p4
 andClippingSize:(CGSize)clipSize
  withResolution:(CGSize)resolution
 withVertexIndex:(GLuint)vertIndex
 andTextureIndex:(GLuint)texIndex {
    [self runBlock:^{

        JotGLTexture* clipping;
        GLuint stencil_rb;

        if (clippingPath) {
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
            UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            // this is an image that's filled white with our path and
            // clear everywhere else
            clipping = [[JotGLTexture alloc] initForImage:image withSize:image.size];
        }
        printOpenGLError();

        GLint currBoundRendBuff = currentlyBoundRenderbuffer;

        if (clippingPath) {
            //
            // prep our context to draw our texture as a quad.
            // now prep to draw the actual texture
            // always draw

            // if we were provided a clippingPath, then we should
            // use it as our stencil when drawing our texture

            // always draw to stencil with correct blend mode
            [self glBlendFuncONE];

            // setup stencil buffers
            glGenRenderbuffers(1, &stencil_rb);
            [self bindRenderbuffer:stencil_rb];
            glRenderbufferStorage(GL_RENDERBUFFER, GL_STENCIL_INDEX8, resolution.width, resolution.height);
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, stencil_rb);

            [self assertCheckFramebuffer];

            // setup the stencil test and alpha test. the stencil test
            // ensures all pixels are turned "on" in the stencil buffer,
            // and the alpha test ensures we ignore transparent pixels
            glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
            glClear(GL_COLOR_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
            glClearStencil(0);
            [self glEnableStencilTest];
            [self glColorMaskRed:GL_FALSE green:GL_FALSE blue:GL_FALSE alpha:GL_FALSE];
            [self glDisableDepthMask];

            [self glStencilFunc:GL_ALWAYS ref:1 mask:1];
            [self glStencilOp:GL_KEEP zfail:GL_KEEP zpass:GL_REPLACE]; // draw 1s on test fail (always)

            [self glStencilMask:0xFF];
            glClear(GL_STENCIL_BUFFER_BIT); // needs mask=0xFF


            // these vertices will stretch the stencil texture
            // across the entire size that we're drawing on
            Vertex3D vertices[] = {
                {p1.x, p1.y},
                {p2.x, p2.y},
                {p3.x, p3.y},
                {p4.x, p4.y}};
            const GLfloat texCoords[] = {
                0, 1,
                1, 1,
                0, 0,
                1, 0};
            // bind our clipping texture, and draw it
            [clipping bind];

            [clipping bindForRenderToQuadWithCanvasSize:resolution forProgram:[self stencilProgram]];

            //            [self glColor4f:1 and:1 and:1 and:1];

            [self enableVertexArrayAtIndex:vertIndex forSize:2 andStride:0 andPointer:vertices];
            [self enableTextureCoordArrayAtIndex:texIndex forSize:2 andStride:0 andPointer:texCoords];
            [self drawTriangleStripCount:4 withProgram:[self stencilProgram]];


            // now setup the next draw operations to respect
            // the new stencil buffer that's setup
            [self glColorMaskRed:GL_TRUE green:GL_TRUE blue:GL_TRUE alpha:GL_TRUE];
            [self glEnableDepthMask];
            [self glStencilMask:0x00];
            [self glStencilFunc:GL_EQUAL ref:1 mask:0xFF];
        }
        printOpenGLError();

        ////////////////////////////
        // stencil is setup
        block();
        //

        printOpenGLError();

        if (clippingPath) {
            ////////////////////////////
            // turn stencil off
            //
            [clipping unbind];
            [self glDisableStencilTest];
            [self unbindRenderbuffer];
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, 0);
            [self deleteRenderbuffer:stencil_rb];

            [self glStencilFunc:GL_ALWAYS ref:0 mask:1];
            [self glStencilOp:GL_KEEP zfail:GL_KEEP zpass:GL_KEEP];

            // restore bound render buffer
            if (currBoundRendBuff) {
                [self bindRenderbuffer:currBoundRendBuff];
            } else {
                [self unbindRenderbuffer];
            }
        }
        printOpenGLError();
    }];
}

#pragma mark - Color and Blend Mode

- (void)glClearColor:(GLfloat)red and:(GLfloat)green and:(GLfloat)blue and:(GLfloat)alpha {
    ValidateCurrentContext;
    if (red != lastClearRed || green != lastClearGreen || blue != lastClearBlue || alpha != lastClearAlpha) {
        glClearColor(red, green, blue, alpha);
        lastClearRed = red;
        lastClearGreen = green;
        lastClearBlue = blue;
        lastClearAlpha = alpha;
    }
    printOpenGLError();
}

- (void)prepOpenGLBlendModeForColor:(UIColor*)color {
    if (!color) {
        // eraser
        [self glBlendFuncZERO];
    } else {
        // normal brush
        [self glBlendFuncONE];
    }
    printOpenGLError();
}

- (void)glBlendFuncONE {
    [self glBlendFunc:GL_ONE and:GL_ONE_MINUS_SRC_ALPHA];
}

- (void)glBlendFuncZERO {
    [self glBlendFunc:GL_ZERO and:GL_ONE_MINUS_SRC_ALPHA];
}

- (void)glBlendFunc:(GLenum)sfactor and:(GLenum)dfactor {
    ValidateCurrentContext;
    if (blend_sfactor != sfactor ||
        blend_dfactor != dfactor) {
        blend_sfactor = sfactor;
        blend_dfactor = dfactor;
        glBlendFunc(blend_sfactor, blend_dfactor);
    }
    printOpenGLError();
}

- (void)glViewportWithX:(GLint)x y:(GLint)y width:(GLsizei)width height:(GLsizei)height {
    ValidateCurrentContext;
    if (viewport_x != x || viewport_y != y || viewport_width != width || viewport_height != height) {
        glViewport(x, y, width, height);
        viewport_x = x;
        viewport_y = y;
        viewport_width = width;
        viewport_height = height;
    }
    printOpenGLError();
}

- (void)clear {
    ValidateCurrentContext;
    [self glClearColor:0 and:0 and:0 and:0];
    glClear(GL_COLOR_BUFFER_BIT);
}

- (void)drawTriangleStripCount:(GLsizei)count withProgram:(JotGLProgram*)program {
    ValidateCurrentContext;
    [program use];
    glDrawArrays(GL_TRIANGLE_STRIP, 0, count);
    printOpenGLError();
}

- (void)drawPointCount:(GLsizei)count withProgram:(JotGLProgram*)program {
    ValidateCurrentContext;
    [program use];
    glDrawArrays(GL_POINTS, 0, count);
    printOpenGLError();
}

- (void)readPixelsInto:(GLubyte*)data ofSize:(GLSize)size {
    glPixelStorei(GL_PACK_ALIGNMENT, 4);

    @autoreleasepool {
        // timing start
        CGFloat duration = BNRTimeBlock2(^{
            glReadPixels(0, 0, size.width, size.height, GL_RGBA, GL_UNSIGNED_BYTE, data);
        });
        DebugLog(@"total2 = %f", duration);
    }
    // timing end
    printOpenGLError();
}

#pragma mark - Generate Assets

- (GLuint)generateTextureForSize:(CGSize)fullPixelSize withBytes:(const GLvoid*)imageData {
    ValidateCurrentContext;
    GLuint textureID = 0;

    // create a new texture in OpenGL
    glGenTextures(1, &textureID);
    printOpenGLError();

    // bind the texture that we'll be writing to
    [self bindTexture:textureID];
    printOpenGLError();

    // configure how this texture scales.
    [self glTexParameteriWithPname:GL_TEXTURE_MIN_FILTER param:GL_LINEAR];
    printOpenGLError();
    [self glTexParameteriWithPname:GL_TEXTURE_MAG_FILTER param:GL_LINEAR];
    printOpenGLError();
    [self glTexParameteriWithPname:GL_TEXTURE_WRAP_S param:GL_CLAMP_TO_EDGE];
    printOpenGLError();
    [self glTexParameteriWithPname:GL_TEXTURE_WRAP_T param:GL_CLAMP_TO_EDGE];
    printOpenGLError();
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fullPixelSize.width, fullPixelSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    printOpenGLError();

    [self unbindTexture];
    printOpenGLError();

    return textureID;
}

- (void)bindTexture:(GLuint)textureId {
    ValidateCurrentContext;
    glBindTexture(GL_TEXTURE_2D, textureId);
    printOpenGLError();
}

- (void)unbindTexture {
    ValidateCurrentContext;
    glBindTexture(GL_TEXTURE_2D, 0);
    printOpenGLError();
}

- (void)deleteTexture:(GLuint)textureId {
    ValidateCurrentContext;
    glDeleteTextures(1, &textureId);
    printOpenGLError();
}

- (GLuint)generateFramebufferWithTextureBacking:(JotGLTexture*)texture {
    __block GLuint framebufferID;
    [self runBlockAndMaintainCurrentFramebuffer:^{
        glGenFramebuffers(1, &framebufferID);
        printOpenGLError();
        if (framebufferID) {
            // generate FBO
            [self bindFramebuffer:framebufferID];
            [texture bind];
            // associate texture with FBO
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture.textureID, 0);
            printOpenGLError();
            [texture unbind];
            printOpenGLError();
        }
        [self assertCheckFramebuffer];
    }];

    return framebufferID;
}

- (GLSize)generateFramebuffer:(GLuint*)viewFramebuffer
              andRenderbuffer:(GLuint*)viewRenderbuffer
         andDepthRenderBuffer:(GLuint*)depthRenderbuffer
                     forLayer:(CALayer<EAGLDrawable>*)layer {
    ValidateCurrentContext;

    GLint backingWidth, backingHeight;

    // Generate IDs for a framebuffer object and a color renderbuffer
    glGenFramebuffers(1, viewFramebuffer);
    printOpenGLError();
    glGenRenderbuffers(1, viewRenderbuffer);
    printOpenGLError();

    [self bindFramebuffer:viewFramebuffer[0]];
    printOpenGLError();
    [self bindRenderbuffer:viewRenderbuffer[0]];
    printOpenGLError();
    // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
    // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
    printOpenGLError();
    [self renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    printOpenGLError();
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, *viewRenderbuffer);
    printOpenGLError();

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    printOpenGLError();
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    printOpenGLError();

    // For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
    glGenRenderbuffers(1, depthRenderbuffer);
    printOpenGLError();
    [self bindRenderbuffer:depthRenderbuffer[0]];
    printOpenGLError();
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
    printOpenGLError();
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, *depthRenderbuffer);
    printOpenGLError();

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        NSAssert(NO, @"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return GLSizeFromCGSize(CGSizeZero);
    }
    printOpenGLError();

    return GLSizeMake(backingWidth, backingHeight);
}

- (void)bindFramebuffer:(GLuint)framebuffer {
    ValidateCurrentContext;
    if (framebuffer && currentlyBoundFramebuffer != framebuffer) {
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        currentlyBoundFramebuffer = framebuffer;
    } else if (!framebuffer) {
        @throw [NSException exceptionWithName:@"GLBindFramebufferExcpetion" reason:@"Trying to bind nil framebuffer" userInfo:nil];
    }
    printOpenGLError();
}
- (void)unbindFramebuffer {
    ValidateCurrentContext;
    if (currentlyBoundFramebuffer != 0) {
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        currentlyBoundFramebuffer = 0;
    }
    printOpenGLError();
}

- (void)deleteFramebuffer:(GLuint)framebufferID {
    ValidateCurrentContext;
    if (framebufferID && currentlyBoundFramebuffer == framebufferID) {
        @throw [NSException exceptionWithName:@"GLDeleteBoundBufferException" reason:@"deleting currently boudn buffer" userInfo:nil];
    }
    glDeleteFramebuffers(1, &framebufferID);
    printOpenGLError();
}

- (void)deleteRenderbuffer:(GLuint)viewRenderbuffer {
    ValidateCurrentContext;
    if (viewRenderbuffer && currentlyBoundRenderbuffer == viewRenderbuffer) {
        @throw [NSException exceptionWithName:@"GLDeleteBoundBufferException" reason:@"deleting currently boudn buffer" userInfo:nil];
    }
    glDeleteRenderbuffers(1, &viewRenderbuffer);
    printOpenGLError();
}

- (void)bindRenderbuffer:(GLuint)renderBufferId {
    ValidateCurrentContext;
    if (renderBufferId && currentlyBoundRenderbuffer != renderBufferId) {
        glBindRenderbuffer(GL_RENDERBUFFER, renderBufferId);
        currentlyBoundRenderbuffer = renderBufferId;
    } else if (!renderBufferId) {
        @throw [NSException exceptionWithName:@"GLBindRenderbufferExceptoin" reason:@"trying to bind nil renderbuffer" userInfo:nil];
    }
    printOpenGLError();
}

- (void)unbindRenderbuffer {
    ValidateCurrentContext;
    if (currentlyBoundRenderbuffer) {
        glBindRenderbuffer(GL_RENDERBUFFER, 0);
        currentlyBoundRenderbuffer = 0;
    }
    printOpenGLError();
}

- (BOOL)presentRenderbuffer {
    ValidateCurrentContext;
    printOpenGLError();
    return [super presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - Assert

- (void)assertCheckFramebuffer {
    ValidateCurrentContext;
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSString* glErrorStr = [NSString stringWithFormat:@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER)];
        DebugLog(@"GL Framebuffer Error: %@", glErrorStr);
        @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:glErrorStr userInfo:nil];
    }
    printOpenGLError();
}

- (void)assertCurrentBoundFramebufferIs:(GLuint)framebufferID andRenderBufferIs:(GLuint)viewRenderbuffer {
    ValidateCurrentContext;
    GLint currBoundFrBuff = -1;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &currBoundFrBuff);
    GLint currBoundRendBuff = -1;
    glGetIntegerv(GL_RENDERBUFFER_BINDING, &currBoundRendBuff);
    if (currBoundFrBuff != framebufferID) {
        @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:[NSString stringWithFormat:@"Expected %d but was %d", framebufferID, currBoundFrBuff] userInfo:nil];
    }
    if (currBoundRendBuff != viewRenderbuffer) {
        @throw [NSException exceptionWithName:@"Renderbuffer Exception" reason:[NSString stringWithFormat:@"Expected %d but was %d", viewRenderbuffer, currBoundRendBuff] userInfo:nil];
    }
    printOpenGLError();
}

#pragma mark - Buffers

static GLsizeiptr zeroedCacheSize = -1;
static void* zeroedDataCache = nil;

- (GLuint)generateArrayBufferForSize:(GLsizeiptr)mallocSize forCacheNumber:(NSInteger)cacheNumber {
    GLuint vbo;
    // zeroedDataCache is a pointer to zero'd memory that we
    // use to initialze our VBO. This prevents "VBO uses uninitialized data"
    // warning in Instruments, and will only waste a few Kb of memory
    if (mallocSize > zeroedCacheSize) {
        @synchronized([JotGLContext class]) {
            if (zeroedDataCache) {
                free(zeroedDataCache);
            }
            zeroedCacheSize = mallocSize;
            zeroedDataCache = calloc(1, mallocSize);
            if (!zeroedDataCache) {
                @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't calloc" userInfo:nil];
            }
        }
    }
    // generate the VBO in OpenGL
    glGenBuffers(1, &vbo);
    [self bindArrayBuffer:vbo];
    @synchronized([JotGLContext class]) {
        // initialize the buffer to zero'd data
        glBufferData(GL_ARRAY_BUFFER, mallocSize, zeroedDataCache, GL_DYNAMIC_DRAW);
    }
    // unbind after alloc
    [self unbindArrayBuffer];
    printOpenGLError();
    return vbo;
}

- (void)bindArrayBuffer:(GLuint)buffer {
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    printOpenGLError();
}

- (void)updateArrayBufferWithBytes:(const GLvoid*)bytes atOffset:(GLintptr)offset andLength:(GLsizeiptr)len {
    glBufferSubData(GL_ARRAY_BUFFER, offset, len, bytes);
    printOpenGLError();
}

- (void)unbindArrayBuffer {
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    printOpenGLError();
}

- (void)deleteArrayBuffer:(GLuint)buffer {
    glDeleteBuffers(1, &buffer);
    printOpenGLError();
}

#pragma mark - Dealloc

- (void)dealloc {
    // allow the context to dealloc on any thread.
    validateThreadBlock = ^{
        return YES;
    };

    [self runBlock:^{
        @autoreleasepool {
            [contextProperties removeAllObjects];
            coloredPointProgram = nil;
            colorlessPointProgram = nil;
            quadProgram = nil;
            stencilProgram = nil;
        }
    }];
}

- (NSString*)description {
    return [NSString stringWithFormat:@"[JotGLContext (%p): %@]", self, name];
}


CGFloat BNRTimeBlock2(void (^block)(void)) {
    mach_timebase_info_data_t info;
    if (mach_timebase_info(&info) != KERN_SUCCESS)
        return -1.0;

    uint64_t start = mach_absolute_time();
    block();
    uint64_t end = mach_absolute_time();
    uint64_t elapsed = end - start;

    uint64_t nanos = elapsed * info.numer / info.denom;
    return (CGFloat)nanos / NSEC_PER_SEC;

} // BNRTimeBlock


@end
