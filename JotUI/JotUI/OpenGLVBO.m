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
#import "AbstractBezierPathElement-Protected.h"

@implementation OpenGLVBO{
    GLuint vbo;
    NSInteger cacheNumber;
    GLsizeiptr mallocSize;
    NSInteger stepMallocSize;
    NSInteger numberOfSteps;
}

static int zeroedCacheNumber = -1;
static void * zeroedDataCache = nil;


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
        
        if(_cacheNumber > zeroedCacheNumber){
            if(zeroedDataCache){
                free(zeroedDataCache);
            }
            zeroedDataCache = calloc(cacheNumber, kJotBufferBucketSize);
        }
        
        glBufferData(GL_ARRAY_BUFFER, mallocSize, zeroedDataCache, GL_DYNAMIC_DRAW);
        printOpenGLError();
    }
    return self;
}


-(BOOL) updateStep:(NSInteger)stepNumber withBufferWithData:(NSData*)vertexData inContext:(JotGLContext*)context{
    [self bindToContext:(JotGLContext*)context forStep:stepNumber];
    GLintptr offset = stepNumber*stepMallocSize;
    GLsizeiptr len = vertexData.length;
    glBufferSubData(GL_ARRAY_BUFFER, offset, len, vertexData.bytes);
    return !printOpenGLError();
}


-(void) bindToContext:(JotGLContext*)context forStep:(NSInteger)stepNumber{
    [context glBindBuffer:GL_ARRAY_BUFFER and:vbo];
    [context glVertexPointer:2 and:GL_FLOAT and:sizeof(struct ColorfulVertex) and:stepNumber*stepMallocSize + offsetof(struct ColorfulVertex, Position)];
    [context glColorPointer:4 and:GL_FLOAT and:sizeof(struct ColorfulVertex) and:stepNumber*stepMallocSize + offsetof(struct ColorfulVertex, Color)];
    [context glPointSizePointerOES:GL_FLOAT and:sizeof(struct ColorfulVertex) and:stepNumber*stepMallocSize + offsetof(struct ColorfulVertex, Size)];
    [context glEnableClientState:GL_VERTEX_ARRAY];
    [context glEnableClientState:GL_COLOR_ARRAY];
    [context glEnableClientState:GL_POINT_SIZE_ARRAY_OES];
    printOpenGLError();
}

-(void) bindToContext:(JotGLContext*)context forColor:(UIColor*)color andStep:(NSInteger)stepNumber{
    [context glBindBuffer:GL_ARRAY_BUFFER and:vbo];
    [context glVertexPointer:2 and:GL_FLOAT and:sizeof(struct ColorlessVertex) and:stepNumber*stepMallocSize + offsetof(struct ColorlessVertex, Position)];
    [context glPointSizePointerOES:GL_FLOAT and:sizeof(struct ColorlessVertex) and:stepNumber*stepMallocSize + offsetof(struct ColorlessVertex, Size)];
    [context glEnableClientState:GL_VERTEX_ARRAY];
    [context glEnableClientState:GL_POINT_SIZE_ARRAY_OES];
    [context glDisableClientState:GL_COLOR_ARRAY];
    
    if(!color){
        [context glColor4f:0 and:0 and:0 and:1];
    }else{
        GLfloat colorSteps[4];
        [color getRGBAComponents:colorSteps];
        if(colorSteps[0] * colorSteps[3] > 1 ||
           colorSteps[1] * colorSteps[3] > 1 ||
           colorSteps[2] * colorSteps[3] > 1 ||
           colorSteps[3] > 1 ||
           colorSteps[0] * colorSteps[3] < 0 ||
           colorSteps[1] * colorSteps[3] < 0 ||
           colorSteps[2] * colorSteps[3] < 0 ||
           colorSteps[3] < 0){
            NSLog(@"what");
        }
        [context glColor4f:colorSteps[0] * colorSteps[3]
                       and:colorSteps[1] * colorSteps[3]
                       and:colorSteps[2] * colorSteps[3]
                       and:colorSteps[3]];
    }
    printOpenGLError();
}

-(void) unbindFromContext:(JotGLContext*)context{
    [context glBindBuffer:GL_ARRAY_BUFFER and:0];
}



-(void) dealloc{
    if(vbo){
        glDeleteBuffers(1,&vbo);
    }
}


@end
