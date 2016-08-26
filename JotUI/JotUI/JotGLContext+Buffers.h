//
//  JotGLContext+Buffers.h
//  JotUI
//
//  Created by Adam Wulf on 2/26/15.
//  Copyright (c) 2015 Milestone Made. All rights reserved.
//

#ifndef JotUI_JotGLContext_Buffers_h
#define JotUI_JotGLContext_Buffers_h

#import "JotGLContext.h"
#import "JotUI.h"
#import <UIKit/UIKit.h>


@interface JotGLContext (Buffers)

- (GLuint)generateArrayBufferForSize:(GLsizeiptr)mallocSize forCacheNumber:(NSInteger)cacheNumber;

- (void)bindArrayBuffer:(GLuint)buffer;

- (void)updateArrayBufferWithBytes:(const GLvoid*)bytes atOffset:(GLintptr)offset andLength:(GLsizeiptr)length;

- (void)unbindArrayBuffer;

- (void)deleteArrayBuffer:(GLuint)buffer;

@end

#endif
