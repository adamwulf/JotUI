//
//  JotGLTexture.h
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JotGLContext.h"

@interface JotGLTexture : NSObject{
    GLuint textureID;
}

@property (readonly) GLuint textureID;
@property (readonly) CGSize pixelSize;

-(id) initForImage:(UIImage*)imageToLoad withSize:(CGSize)size;

-(id) initForTextureID:(GLuint)textureID withSize:(CGSize)size;

-(void) bind;

-(void) drawInContext:(JotGLContext*)context;
-(void) drawInContext:(JotGLContext*)context atP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4 toSize:(CGSize)size;

@end
