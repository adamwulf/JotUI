//
//  JotGLPointProgram.h
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#import <JotUI/JotUI.h>
#import "JotGLProgram.h"


@interface JotGLPointProgram : JotGLProgram

- (id)initWithVertexShaderFilename:(NSString*)vShaderFilename
            fragmentShaderFilename:(NSString*)fShaderFilename
                    withAttributes:(NSArray<NSString*>*)attributes
                       andUniforms:(NSArray<NSString*>*)uniforms;

@property(nonatomic, assign) GLfloat rotation;

- (GLuint)attributeVertexIndex;

- (GLuint)attributePointSizeIndex;

- (GLuint)uniformTextureIndex;

@end
