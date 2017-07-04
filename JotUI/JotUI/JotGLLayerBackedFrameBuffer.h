//
//  JotGLRenderBackedFrameBuffer.h
//  JotUI
//
//  Created by Adam Wulf on 1/29/15.
//  Copyright (c) 2015 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotGLContext.h"
#import "DeleteAssets.h"
#import "AbstractJotGLFrameBuffer.h"


@interface JotGLLayerBackedFrameBuffer : AbstractJotGLFrameBuffer <DeleteAssets>

@property(readonly) CGSize initialViewport;

- (instancetype)init NS_UNAVAILABLE;

- (id)initForLayer:(CALayer<EAGLDrawable>*)layer;

// erase the texture by setting all pixels
// to zero opacity
- (void)clear;

- (void)setNeedsPresentRenderBuffer;

- (void)presentRenderBufferInContext:(JotGLContext*)context;

@end
