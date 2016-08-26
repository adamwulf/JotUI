//
//  JotGLColoredPointProgram.h
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#import <JotUI/JotUI.h>
#import "JotGLPointProgram.h"


@interface JotGLColoredPointProgram : JotGLPointProgram

- (id)init NS_AVAILABLE_IOS(8.1);


- (GLuint)attributeVertexColorIndex;

@end
