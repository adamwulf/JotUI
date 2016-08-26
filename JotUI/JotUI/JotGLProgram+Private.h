//
//  JotGLProgram+Private.h
//  JotUI
//
//  Created by Adam Wulf on 1/5/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#ifndef JotGLProgram_Private_h
#define JotGLProgram_Private_h

#import "JotGLProgram.h"


@interface JotGLProgram ()

+ (GLuint)attributeIndex:(NSString*)attributeName;
- (GLuint)uniformIndex:(NSString*)uniformName;

@end


#endif /* JotGLProgram_Private_h */
