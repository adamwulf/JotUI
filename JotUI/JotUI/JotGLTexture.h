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

-(void) loadImage:(UIImage*)backgroundImage forSize:(CGSize)fullPointSize intoFBO:(GLuint)backgroundFramebuffer;

-(void) bind;

@end
