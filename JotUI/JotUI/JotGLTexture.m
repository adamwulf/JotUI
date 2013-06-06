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
    CGSize fullPixelSize;
}

@synthesize textureID;

-(id) initForImage:(UIImage*)imageToLoad withSize:(CGSize)size{
    if(self = [super init]){
        fullPixelSize = size;
        
        // unload the old texture
        [self unload];
        
        // create a new texture in OpenGL
        glGenTextures(1, &textureID);
        
        // bind the texture that we'll be writing to
        glBindTexture(GL_TEXTURE_2D, textureID);
        
        // configure how this texture scales.
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        //
        // load the image data if we have some, or initialize to
        // a blank texture
        if(imageToLoad){
            //
            // we have an image to load, so draw it to a bitmap context.
            // then we can load those bytes into OpenGL directly.
            // after they're loaded, we can free the memory for our cgcontext.
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            void *imageData = malloc( fullPixelSize.height * fullPixelSize.width * 4 );
            CGContextRef cgContext = CGBitmapContextCreate( imageData, fullPixelSize.width, fullPixelSize.height, 8, 4 * fullPixelSize.width, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
            CGContextTranslateCTM (cgContext, 0, fullPixelSize.height);
            CGContextScaleCTM (cgContext, 1.0, -1.0);
            CGColorSpaceRelease( colorSpace );
            CGContextClearRect( cgContext, CGRectMake( 0, 0, fullPixelSize.width, fullPixelSize.height ) );
            
            // draw the new background in aspect-fill mode
            CGSize backgroundSize = CGSizeMake(CGImageGetWidth(imageToLoad.CGImage), CGImageGetHeight(imageToLoad.CGImage));
            CGFloat horizontalRatio = fullPixelSize.width / backgroundSize.width;
            CGFloat verticalRatio = fullPixelSize.height / backgroundSize.height;
            CGFloat ratio = MAX(horizontalRatio, verticalRatio); //AspectFill
            CGSize aspectFillSize = CGSizeMake(backgroundSize.width * ratio, backgroundSize.height * ratio);
            
            CGContextDrawImage( cgContext,  CGRectMake((fullPixelSize.width-aspectFillSize.width)/2,
                                                       (fullPixelSize.height-aspectFillSize.height)/2,
                                                       aspectFillSize.width,
                                                       aspectFillSize.height), imageToLoad.CGImage );
            // ok, initialize the data
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fullPixelSize.width, fullPixelSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
            
            // cleanup
            CGContextRelease(cgContext);
            free(imageData);
        }else{
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fullPixelSize.width, fullPixelSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        }
        // clear texture bind
        glBindTexture(GL_TEXTURE_2D,0);
    }
    
    return self;
}

-(CGSize) pixelSize{
    return fullPixelSize;
}

-(void) unload{
    if (textureID){
        glDeleteTextures(1, &textureID);
        textureID = 0;
    }
}

-(void) bind{
    if(textureID){
        glBindTexture(GL_TEXTURE_2D, textureID);
    }
}


-(void) draw{
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    Vertex3D vertices[] = {
        { 0.0, fullPixelSize.height},
        { fullPixelSize.width, fullPixelSize.height},
        { 0.0, 0.0},
        { fullPixelSize.width, 0.0}
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
