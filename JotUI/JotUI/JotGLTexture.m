//
//  JotGLTexture.m
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLTexture.h"
#import "JotUI.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@implementation JotGLTexture{
    GLuint backgroundTexture;
    CGSize fullPointSize;
}

-(id) initForSize:(CGSize)size{
    if(self = [super init]){
        fullPointSize = size;
    }
    return self;
}

-(void) unload{
    if (backgroundTexture){
        glDeleteTextures(1, &backgroundTexture);
        backgroundTexture = 0;
    }
}

-(void) loadImage:(UIImage*)backgroundImage intoFBO:(GLuint)backgroundFramebuffer{
    
    // unload the old texture
    [self unload];
    
    // create a new texture in OpenGL
    glGenTextures(1, &backgroundTexture);
    
    // bind the texture that we'll be writing to
    glBindTexture(GL_TEXTURE_2D, backgroundTexture);
    
    // configure how this texture scales.
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    //
    // load the image data if we have some, or initialize to
    // a blank texture
    if(backgroundImage){
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        void *imageData = malloc( fullPointSize.height * fullPointSize.width * 4 );
        CGContextRef cgContext = CGBitmapContextCreate( imageData, fullPointSize.width, fullPointSize.height, 8, 4 * fullPointSize.width, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
        CGContextTranslateCTM (cgContext, 0, fullPointSize.height);
        CGContextScaleCTM (cgContext, 1.0, -1.0);
        CGColorSpaceRelease( colorSpace );
        CGContextClearRect( cgContext, CGRectMake( 0, 0, fullPointSize.width, fullPointSize.height ) );
        
        // draw the new background in aspect-fill mode
        CGSize backgroundSize = CGSizeMake(CGImageGetWidth(backgroundImage.CGImage), CGImageGetHeight(backgroundImage.CGImage));
        CGFloat horizontalRatio = fullPointSize.width / backgroundSize.width;
        CGFloat verticalRatio = fullPointSize.height / backgroundSize.height;
        CGFloat ratio = MAX(horizontalRatio, verticalRatio); //AspectFill
        CGSize aspectFillSize = CGSizeMake(backgroundSize.width * ratio, backgroundSize.height * ratio);
        
        CGContextDrawImage( cgContext,  CGRectMake((fullPointSize.width-aspectFillSize.width)/2,
                                                   (fullPointSize.height-aspectFillSize.height)/2,
                                                   aspectFillSize.width,
                                                   aspectFillSize.height), backgroundImage.CGImage );
        // ok, initialize the data
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fullPointSize.width, fullPointSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
        
        // cleanup
        CGContextRelease(cgContext);
        free(imageData);
    }else{
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fullPointSize.width, fullPointSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    }
    
    if(backgroundFramebuffer){
        // generate FBO
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, backgroundFramebuffer);
        // associate texture with FBO
        glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, backgroundTexture, 0);
    }
    
    // clear texture bind
    glBindTexture(GL_TEXTURE_2D,0);
    
    
    // check if it worked (probably worth doing :) )
    GLuint status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
    if (status != GL_FRAMEBUFFER_COMPLETE_OES)
    {
        // didn't work
        NSLog(@"failed to create texture frame buffer");
    }
}

-(void) bind{
    glBindTexture(GL_TEXTURE_2D, backgroundTexture);
}


-(void) draw{
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    Vertex3D vertices[] = {
        { 0.0, fullPointSize.height},
        { fullPointSize.width, fullPointSize.height},
        { 0.0, 0.0},
        { fullPointSize.width, 0.0}
    };
    static const GLfloat texCoords[] = {
        0.0, 1.0,
        1.0, 1.0,
        0.0, 0.0,
        1.0, 0.0
    };
    
    [self bind];
    
    glVertexPointer(2, GL_FLOAT, 0, vertices);
    glTexCoordPointer(2, GL_FLOAT, 0, texCoords);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
}


-(void) dealloc{
	[self unload];
}

@end
