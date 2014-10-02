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

@interface JotBufferVBO : NSObject

@property (nonatomic, readonly) int fullByteSize;
@property (nonatomic, readonly) NSUInteger allocOrder;

-(id) initWithData:(NSData*)vertexData andOpenGLVBO:(OpenGLVBO*)_vbo andStepNumber:(NSInteger)_stepNumber;

+(int) cacheNumberForBytes:(NSInteger)bytes;

-(NSInteger) cacheNumber;

-(void) updateBufferWithData:(NSData*)vertexData;

-(void) bind;

-(void) bindForColor:(GLfloat[4])color;

-(void) unbind;

@end
