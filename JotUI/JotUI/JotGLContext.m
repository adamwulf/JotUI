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
@implementation JotGLContext{
    CGFloat lastRed;
    CGFloat lastBlue;
    CGFloat lastGreen;
    CGFloat lastAlpha;

    BOOL enabled_GL_VERTEX_ARRAY;
    BOOL enabled_GL_COLOR_ARRAY;
    BOOL enabled_GL_POINT_SIZE_ARRAY_OES;
    BOOL enabled_GL_TEXTURE_COORD_ARRAY;
    
    BOOL needsFlush;
    
    GLenum blend_sfactor;
    GLenum blend_dfactor;
    
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

-(id) initWithAPI:(EAGLRenderingAPI)api andValidateThreadWith:(BOOL(^)())_validateThreadBlock{
    if(self = [super initWithAPI:api]){
        lastRed = -1;
        lastBlue = -1;
        lastGreen = -1;
        lastAlpha = -1;
        validateThreadBlock = _validateThreadBlock;
        lock = [[NSRecursiveLock alloc] init];
        contextProperties = [NSMutableDictionary dictionary];
    }
    return self;
}

-(id) initWithAPI:(EAGLRenderingAPI)api sharegroup:(EAGLSharegroup *)sharegroup andValidateThreadWith:(BOOL(^)())_validateThreadBlock{
    if(self = [super initWithAPI:api sharegroup:sharegroup]){
        lastRed = -1;
        lastBlue = -1;
        lastGreen = -1;
        lastAlpha = -1;
        blend_dfactor = GL_ZERO;
        blend_sfactor = GL_ZERO;
        validateThreadBlock = _validateThreadBlock;
        lock = [[NSRecursiveLock alloc] init];
        contextProperties = [NSMutableDictionary dictionary];
    }
    return self;
}

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

-(void) glColor4f:(GLfloat)red and:(GLfloat)green and:(GLfloat)blue and:(GLfloat) alpha{
    if(red != lastRed || green != lastGreen || blue != lastBlue || alpha != lastAlpha){
        glColor4f(red, green, blue, alpha);
        lastRed = red;
        lastGreen = green;
        lastBlue = blue;
        lastAlpha = alpha;
    }
}

-(void) glEnableClientState:(GLenum)array{
    if(array == GL_VERTEX_ARRAY){
        if(!enabled_GL_VERTEX_ARRAY){
            enabled_GL_VERTEX_ARRAY = YES;
            glEnableClientState(array);
        }
    }else if(array == GL_COLOR_ARRAY){
        if(!enabled_GL_COLOR_ARRAY){
            enabled_GL_COLOR_ARRAY = YES;
            glEnableClientState(array);
            lastAlpha = -1; // need to reset glColor4f http://lwjgl.org/forum/index.php?topic=2424.0
        }
    }else if(array == GL_POINT_SIZE_ARRAY_OES){
        if(!enabled_GL_POINT_SIZE_ARRAY_OES){
            enabled_GL_POINT_SIZE_ARRAY_OES = YES;
            glEnableClientState(array);
        }
    }else if(array == GL_TEXTURE_COORD_ARRAY){
        if(!enabled_GL_TEXTURE_COORD_ARRAY){
            enabled_GL_TEXTURE_COORD_ARRAY = YES;
            glEnableClientState(array);
        }
    }else{
        glEnableClientState(array);
    }
}
    
-(void) glDisableClientState:(GLenum)array{
    if(array == GL_VERTEX_ARRAY){
        if(enabled_GL_VERTEX_ARRAY){
            enabled_GL_VERTEX_ARRAY = NO;
            glDisableClientState(array);
        }
    }else if(array == GL_COLOR_ARRAY){
        if(enabled_GL_COLOR_ARRAY){
            enabled_GL_COLOR_ARRAY = NO;
            glDisableClientState(array);
            lastAlpha = -1; // need to reset glColor4f http://lwjgl.org/forum/index.php?topic=2424.0
        }
    }else if(array == GL_POINT_SIZE_ARRAY_OES){
        if(enabled_GL_POINT_SIZE_ARRAY_OES){
            enabled_GL_POINT_SIZE_ARRAY_OES = NO;
            glDisableClientState(array);
        }
    }else if(array == GL_TEXTURE_COORD_ARRAY){
        if(enabled_GL_TEXTURE_COORD_ARRAY){
            enabled_GL_TEXTURE_COORD_ARRAY = NO;
            glDisableClientState(array);
        }
    }else{
        glDisableClientState(array);
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

@end
