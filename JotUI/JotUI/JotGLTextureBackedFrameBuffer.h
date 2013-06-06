//
//  JotGLTextureBackedFrameBuffer.h
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotGLTexture.h"

@interface JotGLTextureBackedFrameBuffer : NSObject{
    GLuint framebufferID;
}

@property (readonly) GLuint framebufferID;

// initialize a new framebuffer that has its color buffer
// backed by this texture
-(id) initForTexture:(JotGLTexture*)_texture;

// erase the texture by setting all pixels
// to zero opacity
-(void) clear;

// export the buffered texture to disk
-(void) exportTextureOnComplete:(void(^)(UIImage*) )exportFinishBlock;

@end
