//
//  JotGLTexture.h
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface JotGLTexture : NSObject

-(id) initForSize:(CGSize)size;

-(void) loadImage:(UIImage*)backgroundImage intoFBO:(GLuint)backgroundFramebuffer;

-(void) bind;

-(void) draw;

@end
