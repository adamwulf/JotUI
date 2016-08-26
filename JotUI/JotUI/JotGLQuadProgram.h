//
//  JotQuadGLProgram.h
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#import <JotUI/JotUI.h>
#import "JotGLProgram.h"


@interface JotGLQuadProgram : JotGLProgram

- (id)initWithVertexShaderFilename:(NSString*)vShaderFilename
            fragmentShaderFilename:(NSString*)fShaderFilename
                    withAttributes:(NSArray<NSString*>*)attributes
                       andUniforms:(NSArray<NSString*>*)uniforms NS_UNAVAILABLE;

- (id)initWithVertexShaderFilename:(NSString*)vShaderFilename
            fragmentShaderFilename:(NSString*)fShaderFilename;

- (GLuint)attributePositionIndex;

- (GLuint)attributeTextureCoordinateIndex;

- (GLuint)uniformTextureIndex;

@end
