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
@property (readonly) JotGLTexture* texture;

// initialize a new framebuffer that has its color buffer
// backed by this texture
-(id) initForTexture:(JotGLTexture*)texture;

// erase the texture by setting all pixels
// to zero opacity
-(void) clear;

// export the buffered texture to disk
-(void) exportTextureOnComplete:(void(^)(UIImage*) )exportFinishBlock withContext:context;

// should call this method to notify the framebuffer that
// it will be rendered to soon.
//
// this helps optimize the export method, so that it will only
// export if something has been rendered to it
-(void) willRenderToFrameBuffer;

@end
