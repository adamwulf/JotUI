//
//  JotGLPointProgram.m
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#import "JotGLPointProgram.h"
#import "JotGLProgram+Private.h"


@implementation JotGLPointProgram

@synthesize rotation;

- (id)initWithVertexShaderFilename:(NSString*)vShaderFilename fragmentShaderFilename:(NSString*)fShaderFilename withAttributes:(NSArray<NSString*>*)attributes andUniforms:(NSArray<NSString*>*)uniforms {
    if (self = [super initWithVertexShaderFilename:vShaderFilename
                            fragmentShaderFilename:fShaderFilename
                                    withAttributes:[@[@"inVertex", @"pointSize"] arrayByAddingObjectsFromArray:attributes]
                                       andUniforms:[@[@"MVP", @"texture", @"inRotation"] arrayByAddingObjectsFromArray:uniforms]]) {
        self.rotation = 0; // M_PI / 5;
    }
    return self;
}

- (GLuint)attributeVertexIndex {
    return [JotGLProgram attributeIndex:@"inVertex"];
}

- (GLuint)attributePointSizeIndex {
    return [JotGLProgram attributeIndex:@"pointSize"];
}

- (GLuint)uniformTextureIndex {
    return [self uniformIndex:@"texture"];
}

- (GLuint)uniformRotationIndex {
    return [self uniformIndex:@"inRotation"];
}

- (void)use {
    [super use];

    glUniform1f([self uniformRotationIndex], self.rotation);
}

@end
