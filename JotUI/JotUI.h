//
//  JotUI.h
//  JotUI
//
//  Created by Adam Wulf on 12/8/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#ifndef JotUI_h
#define JotUI_h

#define CheckMainThread if(![NSThread isMainThread]){ NSAssert(NO, @"needs to be on main thread"); }

#define kJotEnableCacheStats NO

#define kJotBufferBucketSize 200.0

// vm page size: http://developer.apple.com/library/mac/#documentation/Performance/Conceptual/ManagingMemory/Articles/MemoryAlloc.html
#define kJotMemoryPageSize 4096


#import <Foundation/Foundation.h>

#import <JotTouchSDK/JotStylusManager.h>

#import <JotUI/JotView.h>
#import <JotUI/JotViewDelegate.h>
#import <JotUI/MoveToPathElement.h>
#import <JotUI/CurveToPathElement.h>
#import <JotUI/JotStrokeManager.h>
#import <JotUI/JotGLTextureBackedFrameBuffer.h>
#import <JotUI/JotViewImmutableState.h>
#import <JotUI/JotViewState.h>
#import <JotUI/JotGLContext.h>


typedef struct {
	GLfloat	x;
	GLfloat y;
} Vertex3D;

typedef Vertex3D Vector3D;


#endif
