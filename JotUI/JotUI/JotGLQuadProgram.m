//
//  JotQuadGLProgram.m
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Adonit. All rights reserved.
//

#import "JotGLQuadProgram.h"
#import "JotGLProgram+Private.h"

@implementation JotGLQuadProgram

-(id) initWithVertexShaderFilename:(NSString *)vShaderFilename fragmentShaderFilename:(NSString *)fShaderFilename{
    if(self = [super initWithVertexShaderFilename:vShaderFilename
                           fragmentShaderFilename:fShaderFilename
                                   withAttributes:@[@"position", @"inputTextureCoordinate"]
                                      andUniforms:@[@"MVP", @"texture"]]){

    }
    return self;
}

-(GLuint) attributePositionIndex{
    return [self attributeIndex:@"position"];
}

-(GLuint) attributeTextureCoordinateIndex{
    return [self attributeIndex:@"inputTextureCoordinate"];
}

-(GLuint) uniformTextureIndex{
    return [self uniformIndex:@"texture"];
}

@end
