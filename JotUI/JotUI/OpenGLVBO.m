//
//  OpenGLVBO.m
//  JotUI
//
//  Created by Adam Wulf on 8/6/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "OpenGLVBO.h"
#import "JotUI.h"
#import "UIColor+JotHelper.h"

@implementation OpenGLVBO{
    GLuint vbo;
    NSInteger cacheNumber;
    NSInteger mallocSize;
    NSInteger stepMallocSize;
    NSInteger numberOfSteps;
}

@synthesize numberOfSteps;

-(id) initForCacheNumber:(NSInteger)_cacheNumber{
    if(self = [super init]){
        cacheNumber = _cacheNumber;
        stepMallocSize = cacheNumber * kJotBufferBucketSize;
        mallocSize = ceilf(stepMallocSize / ((float)kJotMemoryPageSize)) * kJotMemoryPageSize;
        numberOfSteps = floorf(mallocSize / stepMallocSize);

        glGenBuffers(1,&vbo);
        glBindBuffer(GL_ARRAY_BUFFER,vbo);
        // create buffer of size mallocSize (init w/ NULL to create)
        glBufferData(GL_ARRAY_BUFFER, mallocSize, NULL, GL_DYNAMIC_DRAW);
    }
    return self;
}


-(void) updateStep:(NSInteger)stepNumber withBufferWithData:(NSData*)vertexData{
    [self bindForStep:stepNumber];
    glBufferSubData(GL_ARRAY_BUFFER, stepNumber*stepMallocSize, vertexData.length, vertexData.bytes);
}


-(void) bindForStep:(NSInteger)stepNumber{
    glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glVertexPointer(2, GL_FLOAT, sizeof(struct ColorfulVertex), stepNumber*stepMallocSize + offsetof(struct ColorfulVertex, Position));
    glColorPointer(4, GL_FLOAT, sizeof(struct ColorfulVertex), stepNumber*stepMallocSize + offsetof(struct ColorfulVertex, Color));
    glPointSizePointerOES(GL_FLOAT, sizeof(struct ColorfulVertex), stepNumber*stepMallocSize + offsetof(struct ColorfulVertex, Size));
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_POINT_SIZE_ARRAY_OES);
}

-(void) bindForColor:(UIColor*)color andStep:(NSInteger)stepNumber{
    glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glVertexPointer(2, GL_FLOAT, sizeof(struct ColorlessVertex), stepNumber*stepMallocSize + offsetof(struct ColorlessVertex, Position));
    glPointSizePointerOES(GL_FLOAT, sizeof(struct ColorlessVertex), stepNumber*stepMallocSize + offsetof(struct ColorlessVertex, Size));
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_POINT_SIZE_ARRAY_OES);
    glDisableClientState(GL_COLOR_ARRAY);
    
    if(!color){
        glColor4f(0, 0, 0, 1);
    }else{
        GLfloat colorSteps[4];
        [color getRGBAComponents:colorSteps];
        glColor4f(colorSteps[0], colorSteps[1], colorSteps[2], colorSteps[3]);
    }
}

-(void) unbind{
    glBindBuffer(GL_ARRAY_BUFFER,0);
}



-(void) dealloc{
    if(vbo){
        glDeleteBuffers(1,&vbo);
    }
}


@end
