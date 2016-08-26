//
//  JotGLColorlessPointProgram.h
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#import <JotUI/JotUI.h>
#import "JotGLProgram.h"
#import "JotGLPointProgram.h"


@interface JotGLColorlessPointProgram : JotGLPointProgram

@property(nonatomic, assign) GLfloat colorRed;
@property(nonatomic, assign) GLfloat colorGreen;
@property(nonatomic, assign) GLfloat colorBlue;
@property(nonatomic, assign) GLfloat colorAlpha;

- (GLuint)uniformVertexColorIndex;

@end
