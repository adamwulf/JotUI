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

@interface OpenGLVBO : NSObject

@property (nonatomic, readonly) int fullByteSize;
@property (nonatomic, readonly) int stepByteSize;
@property (nonatomic, readonly) NSInteger numberOfSteps;
@property (nonatomic, readonly) NSInteger cacheNumber;

+(int) numberOfStepsForCacheNumber:(NSInteger)cacheNumber;

-(id) initForCacheNumber:(NSInteger)cacheNumber;

-(void) updateStep:(NSInteger)stepNumber withBufferWithData:(NSData*)vertexData;

-(void) bindForStep:(NSInteger)stepNumber;

-(void) bindForColor:(GLfloat[4])color andStep:(NSInteger)stepNumber;

-(void) unbind;

@end
