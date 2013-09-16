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

//
// one option would be to load the dict +
// generate a JotGLTexture at the same time
// on different background threads,
// then when they're both done continue on
// the main thread and ask the drawable view to
// loadImage: andState:
//
// the cost of the archiving can probably be minimized,
// but the cost of generating a CGImage for the texture
// probably can't (b/c i need to inflate the saved PNG
// somewhere.)
//
// this guy might have a much faster way to load a png
// into an opengl texture:
// http://stackoverflow.com/questions/16847680/extract-opengl-raw-rgba-texture-data-from-png-data-stored-in-nsdata-using-libp
//
// https://gist.github.com/joshcodes/5681512
//
// http://iphonedevelopment.blogspot.no/2008/10/iphone-optimized-pngs.html
//
// http://blog.nobel-joergensen.com/2010/11/07/loading-a-png-as-texture-in-opengl-using-libpng/
//
//
// right now, unarchiving is taking longer than loading
// the texture.
// if i can write the texture + load the archive
// in parallel, then i should be able to get a texture
// loaded in ~90ms hopefully.
//

-(id) initForImage:(UIImage*)imageToLoad withSize:(CGSize)size inContext:(JotGLContext*)context{
    if(self = [super init]){
        fullPixelSize = size;
        
        // unload the old texture
        [self unloadFromContext:context];
        
        // create a new texture in OpenGL
        [context glGenTextures:1 and:&textureID];
        
        // bind the texture that we'll be writing to
        [context glBindTexture:GL_TEXTURE_2D and:textureID];
        
        // configure how this texture scales.
        [context glTexParameteri:GL_TEXTURE_2D and:GL_TEXTURE_MIN_FILTER and:GL_LINEAR];
        [context glTexParameteri:GL_TEXTURE_2D and:GL_TEXTURE_MAG_FILTER and:GL_LINEAR];
        [context glTexParameteri:GL_TEXTURE_2D and:GL_TEXTURE_WRAP_S and:GL_CLAMP_TO_EDGE];
        [context glTexParameteri:GL_TEXTURE_2D and:GL_TEXTURE_WRAP_T and:GL_CLAMP_TO_EDGE];
        
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
            [context glTexImage2D:GL_TEXTURE_2D and:0 and:GL_RGBA and:fullPixelSize.width and:fullPixelSize.height and:0 and:GL_RGBA and:GL_UNSIGNED_BYTE and:imageData];
            
            // cleanup
            CGContextRelease(cgContext);
            free(imageData);
        }else{
            // init w/ empty data
            void* texels = calloc(fullPixelSize.width * fullPixelSize.height,4);
            [context glTexImage2D:GL_TEXTURE_2D and:0 and:GL_RGBA and:fullPixelSize.width and:fullPixelSize.height and:0 and:GL_RGBA and:GL_UNSIGNED_BYTE and:texels];
            free(texels);
        }
        // clear texture bind
        [context glBindTexture:GL_TEXTURE_2D and:0];
    }
    
    return self;
}

-(CGSize) pixelSize{
    return fullPixelSize;
}

-(void) unloadFromContext:(JotGLContext*)context{
    if (textureID){
        [context glDeleteTextures:1 and:&textureID];
        textureID = 0;
    }
}

-(void) bindToContext:(JotGLContext*)context{
    if(textureID){
        [context glBindTexture:GL_TEXTURE_2D and:textureID];
    }
}


-(void) drawInContext:(JotGLContext*)context{
    [context glBlendFunc:GL_ONE and:GL_ONE_MINUS_SRC_ALPHA];
    [context glEnableClientState:GL_VERTEX_ARRAY];
    [context glEnableClientState:GL_TEXTURE_COORD_ARRAY];
    [context glDisableClientState:GL_COLOR_ARRAY];
    [context glColor4f:1 and:1 and:1 and:1];
    Vertex3D vertices[] = {
        { 0.0, fullPixelSize.height},
        { fullPixelSize.width, fullPixelSize.height},
        { 0.0, 0.0},
        { fullPixelSize.width, 0.0}
    };
    static const GLshort texCoords[] = {
        0, 1,
        1, 1,
        0, 0,
        1, 0
    };
    
    [self bindToContext:context];
    
    [context glVertexPointer:2 and:GL_FLOAT and:0 and:vertices];
    glTexCoordPointer(2, GL_SHORT, 0, texCoords);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [context glDisableClientState:GL_VERTEX_ARRAY];
    [context glDisableClientState:GL_TEXTURE_COORD_ARRAY];
}


-(void) dealloc{
	[self unloadFromContext:(JotGLContext*)[JotGLContext currentContext]];
}

@end
