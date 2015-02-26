//
//  JotGLTextureBackedFrameBuffer.h
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotGLTexture.h"
#import "DeleteAssets.h"
#import "AbstractJotGLFrameBuffer.h"

@interface JotGLTextureBackedFrameBuffer : AbstractJotGLFrameBuffer<DeleteAssets>

@property (readonly) JotGLTexture* texture;

- (instancetype)init NS_UNAVAILABLE;

// initialize a new framebuffer that has its color buffer
// backed by this texture
-(id) initForTexture:(JotGLTexture*)texture forSize:(GLSize)fullSize;

// erase the texture by setting all pixels
// to zero opacity
-(void) clear;

@end
