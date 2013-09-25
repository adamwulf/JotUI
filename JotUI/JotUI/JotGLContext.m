//
//  JotGLContext.m
//  JotUI
//
//  Created by Adam Wulf on 9/23/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLContext.h"
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
}

-(id) initWithAPI:(EAGLRenderingAPI)api{
    if(self = [super initWithAPI:api]){
        lastRed = -1;
        lastBlue = -1;
        lastGreen = -1;
        lastAlpha = -1;
    }
    return self;
}

-(id) initWithAPI:(EAGLRenderingAPI)api sharegroup:(EAGLSharegroup *)sharegroup{
    if(self = [super initWithAPI:api sharegroup:sharegroup]){
        lastRed = -1;
        lastBlue = -1;
        lastGreen = -1;
        lastAlpha = -1;
    }
    return self;
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

@end
