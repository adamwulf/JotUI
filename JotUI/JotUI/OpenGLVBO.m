//
//  OpenGLVBO.m
//  JotUI
//
//  Created by Adam Wulf on 8/6/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "OpenGLVBO.h"
#import "JotUI/JotUI.h"
#import "UIColor+JotHelper.h"
#import "AbstractBezierPathElement-Protected.h"
#import "JotBufferManager.h"
#import "JotGLContext+Buffers.h"
#include <stddef.h>

/**
 * an OpenGLVBO serves as a backing store for (potentially) multiple
 * JotBufferVBOs
 *
 * this buffer will allocate a larger chunk of memory, which it'll split
 * into multiple smaller buffers of equal size. This way, one allocation
 * can be used to back multiple VBOs
 *
 * all VBOs assume the use of ColorfulVertex or ColorlessVertex
 */
@implementation OpenGLVBO{
    // this is the vbo id in OpenGL
    GLuint vbo;
    // this is the number that will determine our malloc size, both total and step
    NSInteger cacheNumber;
    // this will track the entire size of our malloc'd memory
    GLsizeiptr mallocSize;
    // this is the size of a single step of memory
    NSInteger stepMallocSize;
    // this tracks the number of steps that we hold. stepMallocSize * numberOfSteps == mallocSize
    NSInteger numberOfSteps;
    // lock the buffer
    NSLock* lock;
}

@synthesize numberOfSteps;
@synthesize cacheNumber;
@synthesize vbo;

-(id) initForCacheNumber:(NSInteger)_cacheNumber{
    if(self = [super init]){
        [JotGLContext runBlock:^(JotGLContext* context){
            // calculate all of our memory bucket sizes
            cacheNumber = _cacheNumber;
            stepMallocSize = cacheNumber * kJotBufferBucketSize;
            mallocSize = ceilf(stepMallocSize / ((float)kJotMemoryPageSize)) * kJotMemoryPageSize;
            numberOfSteps = floorf(mallocSize / stepMallocSize);
            lock = [[NSLock alloc] init];
            [lock lock];

            // create buffer of size mallocSize (init w/ NULL to create)
            vbo = [context generateArrayBufferForSize:mallocSize forCacheNumber:cacheNumber];

            [lock unlock];
        }];
    }
    return self;
}

+(int) numberOfStepsForCacheNumber:(NSInteger)cacheNumber{
    int stepMallocSize = cacheNumber * kJotBufferBucketSize;
    int mallocSize = ceilf(stepMallocSize / ((float)kJotMemoryPageSize)) * kJotMemoryPageSize;
    int numberOfSteps = floorf(mallocSize / stepMallocSize);
    return numberOfSteps;
}

-(int) fullByteSize{
    return (int) mallocSize;
}

-(int) stepByteSize{
    return (int) stepMallocSize;
}



/**
 * this will update a single step of data inside the VBO.
 * no other steps are affected
 */
-(void) updateStep:(NSInteger)stepNumber withBufferWithData:(NSData*)vertexData{
    [JotGLContext runBlock:^(JotGLContext* context){
        if(!lock){
            NSLog(@"what");
        }
        [lock lock];
        GLintptr offset = stepNumber*stepMallocSize;
        GLsizeiptr len = vertexData.length;
        [context bindArrayBuffer:vbo];
        [context updateArrayBufferWithBytes:vertexData.bytes atOffset:offset andLength:len];
        [context unbindArrayBuffer];
        [context flush];
        [lock unlock];
    }];
}


/**
 * this will bind the VBO with pointers to the input step number,
 * and will prep the client state and pointers appropriately
 *
 * this assumes the VBO is filled with ColorfulVertex vertex data
 */
-(void) bindForStep:(NSInteger)stepNumber{
    [JotGLContext runBlock:^(JotGLContext* context){
        if(!lock){
            NSLog(@"what");
        }
        [lock lock];
        [context bindArrayBuffer:vbo];
        [context enableVertexArrayForSize:2 andStride:sizeof(struct ColorfulVertex) andPointer:(void*)(stepNumber*stepMallocSize + offsetof(struct ColorfulVertex, Position))];
        [context enablePointSizeArrayForStride:sizeof(struct ColorfulVertex) andPointer:(void*)(stepNumber*stepMallocSize + offsetof(struct ColorfulVertex, Size))];
        [context enableColorArrayForSize:4 andStride:sizeof(struct ColorfulVertex) andPointer:(void*)(stepNumber*stepMallocSize + offsetof(struct ColorfulVertex, Color))];
        [context disableTextureCoordArray];
    }];
}

/**
 * this will bind the VBO with pointers for the input step number,
 * and will prep the client state and pointers appropriately
 *
 * this will also set glColor4f for the input color, and assumes
 * that the VBO is filled with ColorlessVertex vertex data
 */
-(void) bindForColor:(GLfloat[4])color andStep:(NSInteger)stepNumber{
    [JotGLContext runBlock:^(JotGLContext* context){
        if(!lock){
            NSLog(@"what");
        }
        [lock lock];
        
        [context bindArrayBuffer:vbo];
        
        [context enableVertexArrayForSize:2 andStride:sizeof(struct ColorlessVertex) andPointer:(void*)(stepNumber*stepMallocSize + offsetof(struct ColorlessVertex, Position))];
        [context enablePointSizeArrayForStride:sizeof(struct ColorlessVertex) andPointer:(void*)(stepNumber*stepMallocSize + offsetof(struct ColorlessVertex, Size))];
        [context disableColorArray];
        [context disableTextureCoordArray];

        [context glColor4f:color[0] and:color[1] and:color[2] and:color[3]];
    }];
}

-(void) unbind{
    if(!lock){
        NSLog(@"what");
    }
    [JotGLContext runBlock:^(JotGLContext* context){
        [context unbindArrayBuffer];
    }];
    [lock unlock];
}

-(void) dealloc{
    if(vbo){
        [[JotBufferManager sharedInstance] openGLBufferHasDied:self];
        [JotGLContext runBlock:^(JotGLContext* context){
            [context deleteBuffer:vbo];
        }];
    }
}


@end
