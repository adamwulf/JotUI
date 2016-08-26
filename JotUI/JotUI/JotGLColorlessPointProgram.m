//
//  JotGLColorlessPointProgram.m
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#import "JotGLColorlessPointProgram.h"
#import "JotGLProgram+Private.h"


@implementation JotGLColorlessPointProgram {
    BOOL hasCalculatedColorComponents;
    GLfloat brushColor[4];
}

- (id)init {
    if (self = [super initWithVertexShaderFilename:@"colorlesspoint"
                            fragmentShaderFilename:@"point"
                                    withAttributes:@[]
                                       andUniforms:@[@"vertexColor"]]) {
        // add vertexColor uniform to the default uniforms
    }
    return self;
}

- (GLuint)uniformVertexColorIndex {
    return [self uniformIndex:@"vertexColor"];
}

- (void)use {
    [super use];

    brushColor[0] = self.colorRed;
    brushColor[1] = self.colorGreen;
    brushColor[2] = self.colorBlue;
    brushColor[3] = self.colorAlpha;
    // initialize brush color
    glUniform4fv([self uniformVertexColorIndex], 1, brushColor);
}

@end
