//
//  JotUI.h
//  JotUI
//
//  Created by Adam Wulf on 12/8/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#ifndef JotUI_h
#define JotUI_h

#import <Foundation/Foundation.h>

#import <JotTouchSDK/JotStylusManager.h>

#import "JotView.h"
#import "JotViewDelegate.h"
#import "MoveToPathElement.h"
#import "JotStrokeManager.h"
#import "JotGLTextureBackedFrameBuffer.h"

typedef struct {
	GLfloat	x;
	GLfloat y;
} Vertex3D;

typedef Vertex3D Vector3D;


#endif
