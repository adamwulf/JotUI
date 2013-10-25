//
//  JotBrushTexture.m
//  JotUI
//
//  Created by Adam Wulf on 6/10/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotBrushTexture.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>


#define kAbstractMethodException [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil]


@implementation JotBrushTexture{
    // OpenGL texure for the brush
	GLuint	glBrushTextureID;
    NSString* name;
}

-(UIImage*) texture{
    @throw kAbstractMethodException;
}

-(NSString*) name{
    if(!name){
        name = NSStringFromClass([self class]);
    }
    return name;
}

#pragma mark - binding

-(BOOL) bind{
    // check if we already have the texture generated
    if(glBrushTextureID){
        glBindTexture(GL_TEXTURE_2D, glBrushTextureID);
        return YES;
    }
    
    //
    // ok, we need to generate the texture to bind it
    //
    // fetch the cgimage for us to draw into a texture
    CGImageRef brushCGImage = self.texture.CGImage;
    // Make sure the image exists
    if(brushCGImage) {
        // Get the width and height of the image
        size_t width = CGImageGetWidth(brushCGImage);
        size_t height = CGImageGetHeight(brushCGImage);
        
        // Texture dimensions must be a power of 2. If you write an application that allows users to supply an image,
        // you'll want to add code that checks the dimensions and takes appropriate action if they are not a power of 2.
        
        // Allocate  memory needed for the bitmap context
        // calloc will zero out all the memory, so we don't have to
        // manually clear it w/ core graphics
        GLubyte* brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
        // Use  the bitmatp creation function provided by the Core Graphics framework.
        CGContextRef brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushCGImage), (CGBitmapInfo) kCGImageAlphaPremultipliedLast);
        // After you create the context, you can draw the  image to the context.
        CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushCGImage);
        // You don't need the context at this point, so you need to release it to avoid memory leaks.
        CGContextRelease(brushContext);
        // Use OpenGL ES to generate a name for the texture.
        glGenTextures(1, &glBrushTextureID);
        // Bind the texture name.
        glBindTexture(GL_TEXTURE_2D, glBrushTextureID);
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // Specify a 2D texture image, providing the a pointer to the image data in memory
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
        
        // Release  the image data; it's no longer needed
        free(brushData);
        glFlush();
        return YES;
    }
    return NO;
}

-(void) unbind{
    if(glBrushTextureID){
        glBindTexture(GL_TEXTURE_2D, 0);
        glBrushTextureID = 0;
    }
}

-(void) dealloc{
    if (glBrushTextureID){
		glDeleteTextures(1, &glBrushTextureID);
		glBrushTextureID = 0;
	}
}


#pragma mark - PlistSaving

-(NSDictionary*) asDictionary{
    return [NSDictionary dictionaryWithObject:NSStringFromClass([self class]) forKey:@"class"];
}

-(id) initFromDictionary:(NSDictionary*)dictionary{
    NSString* className = [dictionary objectForKey:@"class"];
    Class clz = NSClassFromString(className);
    return [clz sharedInstace];
}

#pragma mark - Singleton

+(JotBrushTexture*) sharedInstace{
    @throw kAbstractMethodException;
}


@end
