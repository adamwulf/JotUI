//
//  JotBufferVBO.h
//  JotUI
//
//  Created by Adam Wulf on 7/20/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "UIColor+JotHelper.h"
#import "OpenGLVBO.h"
#import "JotGLContext.h"

@interface JotBufferVBO : NSObject

-(id) initWithData:(NSData*)vertexData andOpenGLVBO:(OpenGLVBO*)_vbo andStepNumber:(NSInteger)_stepNumber inContext:(JotGLContext*)context;

+(int) cacheNumberForBytes:(int)bytes;

-(int) cacheNumber;

-(void) updateBufferInContext:(JotGLContext*)context withData:(NSData*)vertexData;

-(void) bindToContext:(JotGLContext*)context;

-(void) bindToContext:(JotGLContext*)context forColor:(UIColor*)color;

-(void) unbindFromContext:(JotGLContext*)context;

@end
