//
//  OpenGLVBO.h
//  JotUI
//
//  Created by Adam Wulf on 8/6/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "JotGLContext.h"

@interface OpenGLVBO : NSObject

@property (nonatomic, readonly) NSInteger numberOfSteps;

-(id) initForCacheNumber:(NSInteger)_cacheNumber;

-(BOOL) updateStep:(NSInteger)stepNumber withBufferWithData:(NSData*)vertexData inContext:(JotGLContext*)context;

-(void) bindToContext:(JotGLContext*)context forStep:(NSInteger)stepNumber;

-(void) bindToContext:(JotGLContext*)context forColor:(UIColor*)color andStep:(NSInteger)stepNumber;

-(void) unbindFromContext:(JotGLContext*)context;

@end
