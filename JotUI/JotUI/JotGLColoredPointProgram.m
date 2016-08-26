//
//  JotGLColoredPointProgram.m
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#import "JotGLColoredPointProgram.h"
#import "JotGLProgram+Private.h"


@implementation JotGLColoredPointProgram

- (id)init {
    if (self = [super initWithVertexShaderFilename:@"coloredpoint"
                            fragmentShaderFilename:@"point"
                                    withAttributes:@[@"inVertexColor"]
                                       andUniforms:@[@"rotation"]]) {
        // add inVertexColor uniform to the default uniforms
    }
    return self;
}


- (GLuint)attributeVertexColorIndex {
    return [JotGLProgram attributeIndex:@"inVertexColor"];
}


@end
