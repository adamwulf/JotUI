//
//  JotGLPointProgram.m
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Adonit. All rights reserved.
//

#import "JotGLPointProgram.h"
#import "JotGLProgram+Private.h"

@implementation JotGLPointProgram

-(id) initWithVertexShaderFilename:(NSString *)vShaderFilename fragmentShaderFilename:(NSString *)fShaderFilename{
    if(self = [super initWithVertexShaderFilename:vShaderFilename
                           fragmentShaderFilename:fShaderFilename
                                   withAttributes:@[@"inVertex", @"pointSize"]
                                      andUniforms:@[@"MVP", @"vertexColor", @"texture"]]){

    }
    return self;
}

-(GLuint) attributeVertexIndex{
    return [self attributeIndex:@"inVertex"];
}

-(GLuint) attributePointSizeIndex{
    return [self attributeIndex:@"pointSize"];
}

-(GLuint) uniformTextureIndex{
    return [self uniformIndex:@"texture"];
}

-(GLuint) uniformMVPIndex{
    return [self uniformIndex:@"MVP"];
}

-(GLuint) uniformVertexColorIndex{
    return [self uniformIndex:@"vertexColor"];
}

@end
