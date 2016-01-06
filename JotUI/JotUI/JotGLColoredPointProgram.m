//
//  JotGLColoredPointProgram.m
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Adonit. All rights reserved.
//

#import "JotGLColoredPointProgram.h"
#import "JotGLProgram+Private.h"

@implementation JotGLColoredPointProgram

-(id) init{
    if(self = [super initWithVertexShaderFilename:@"coloredpoint"
                           fragmentShaderFilename:@"point"
                                   withAttributes:@[@"inVertexColor"]
                                      andUniforms:@[]]){
        // add inVertexColor uniform to the default uniforms
    }
    return self;
}


-(GLuint) attributeVertexColorIndex{
    return [self attributeIndex:@"inVertexColor"];
}


@end
