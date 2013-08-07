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

-(id) initWithData:(NSData*)vertexData andOpenGLVBO:(OpenGLVBO*)_vbo andStepNumber:(NSInteger)_stepNumber;

+(int) cacheNumberForBytes:(int)bytes;

-(int) cacheNumber;

-(void) updateBufferWithData:(NSData*)vertexData;

-(void) bind;

-(void) bindForColor:(UIColor*)color;

-(void) unbind;

@end
