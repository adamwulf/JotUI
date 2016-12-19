//
//  OpenGLVBO.m
//  JotUI
//
//  Created by Adam Wulf on 8/6/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import "OpenGLVBO.h"
#import "JotUI/JotUI.h"
#import "UIColor+JotHelper.h"
#import "AbstractBezierPathElement-Protected.h"
#import "JotBufferManager.h"
#import "JotGLContext+Buffers.h"
#import "JotGLColorlessPointProgram.h"
#import "JotGLColoredPointProgram.h"
#include <stddef.h>


@interface OpenGLBuffer : NSObject

@property(readonly) GLuint vbo;
@property(readonly) GLsizeiptr mallocSize;

- (id)initForBuffer:(GLuint)vbo withSize:(GLsizeiptr)mallocSize;

@end


@implementation OpenGLBuffer {
    // this is the vbo id in OpenGL
    GLuint vbo;
    // this is the number that will determine our malloc size, both total and step
    // this will track the entire size of our malloc'd memory
    GLsizeiptr mallocSize;
}

@synthesize vbo;
@synthesize mallocSize;

- (id)initForBuffer:(GLuint)_vbo withSize:(GLsizeiptr)_mallocSize {
    if (self = [super init]) {
        mallocSize = _mallocSize;
        vbo = _vbo;
    }
    return self;
}

- (void)deleteAssets {
    if (vbo) {
        [JotGLContext runBlock:^(JotGLContext* context) {
            [context deleteArrayBuffer:vbo];
        }];
        vbo = 0;
    }
}

- (void)dealloc {
    [self deleteAssets];
}

@end


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
@implementation OpenGLVBO {
    // the buffer itself
    OpenGLBuffer* glBuffer;
    // this is the number that will determine our malloc size, both total and step
    NSInteger cacheNumber;
    // this is the size of a single step of memory
    NSInteger stepMallocSize;
    // this tracks the number of steps that we hold. stepMallocSize * numberOfSteps == mallocSize
    NSInteger numberOfSteps;
    // lock the buffer
    NSLock* lock;
}

@synthesize numberOfSteps;
@synthesize cacheNumber;

- (id)initForCacheNumber:(NSInteger)_cacheNumber {
    if (self = [super init]) {
        [JotGLContext runBlock:^(JotGLContext* context) {
            // calculate all of our memory bucket sizes
            cacheNumber = _cacheNumber;
            stepMallocSize = cacheNumber * kJotBufferBucketSize;
            GLsizeiptr mallocSize = ceilf(stepMallocSize / ((float)kJotMemoryPageSize)) * kJotMemoryPageSize;
            numberOfSteps = floorf(mallocSize / stepMallocSize);
            lock = [[NSLock alloc] init];
            [lock lock];

            // create buffer of size mallocSize (init w/ NULL to create)
            GLuint vbo = [context generateArrayBufferForSize:mallocSize forCacheNumber:cacheNumber];

            glBuffer = [[OpenGLBuffer alloc] initForBuffer:vbo withSize:mallocSize];

            [lock unlock];
        }];
    }
    return self;
}

+ (int)numberOfStepsForCacheNumber:(NSInteger)cacheNumber {
    int stepMallocSize = cacheNumber * kJotBufferBucketSize;
    int mallocSize = ceilf(stepMallocSize / ((float)kJotMemoryPageSize)) * kJotMemoryPageSize;
    int numberOfSteps = floorf(mallocSize / stepMallocSize);
    return numberOfSteps;
}

- (GLuint)vbo {
    return glBuffer.vbo;
}

- (int)fullByteSize {
    return (int)glBuffer.mallocSize;
}

- (int)stepByteSize {
    return (int)stepMallocSize;
}


/**
 * this will update a single step of data inside the VBO.
 * no other steps are affected
 */
- (void)updateStep:(NSInteger)stepNumber withBufferWithData:(NSData*)vertexData {
    [JotGLContext runBlock:^(JotGLContext* context) {
        NSAssert(lock, @"must have a lock");
        [lock lock];
        GLintptr offset = stepNumber * stepMallocSize;
        GLsizeiptr len = vertexData.length;
        [context bindArrayBuffer:glBuffer.vbo];
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
- (void)bindForStep:(NSInteger)stepNumber {
    [JotGLContext runBlock:^(JotGLContext* context) {
        NSAssert(lock, @"must have a lock");
        [lock lock];
        [context bindArrayBuffer:glBuffer.vbo];

        [[context coloredPointProgram] use];

        [context enableVertexArrayAtIndex:[[context coloredPointProgram] attributeVertexIndex]
                                  forSize:2
                                andStride:sizeof(struct ColorfulVertex)
                               andPointer:(void*)(stepNumber * stepMallocSize + offsetof(struct ColorfulVertex, Position))];
        [context enableColorArrayAtIndex:[[context coloredPointProgram] attributeVertexColorIndex]
                                 forSize:4
                               andStride:sizeof(struct ColorfulVertex)
                              andPointer:(void*)(stepNumber * stepMallocSize + offsetof(struct ColorfulVertex, Color))];
        [context enablePointSizeArrayAtIndex:[[context coloredPointProgram] attributePointSizeIndex]
                                   forStride:sizeof(struct ColorfulVertex)
                                  andPointer:(void*)(stepNumber * stepMallocSize + offsetof(struct ColorfulVertex, Size))];
    }];
}

/**
 * this will bind the VBO with pointers for the input step number,
 * and will prep the client state and pointers appropriately
 *
 * this will also set glColor4f for the input color, and assumes
 * that the VBO is filled with ColorlessVertex vertex data
 */
- (void)bindForColor:(GLfloat[4])color andStep:(NSInteger)stepNumber {
    [JotGLContext runBlock:^(JotGLContext* context) {
        NSAssert(lock, @"must have a lock");
        [lock lock];

        [[context colorlessPointProgram] use];

        [context bindArrayBuffer:glBuffer.vbo];

        [context enableVertexArrayAtIndex:[[context colorlessPointProgram] attributeVertexIndex]
                                  forSize:2
                                andStride:sizeof(struct ColorlessVertex)
                               andPointer:(void*)(stepNumber * stepMallocSize + offsetof(struct ColorlessVertex, Position))];
        [context enablePointSizeArrayAtIndex:[[context colorlessPointProgram] attributePointSizeIndex]
                                   forStride:sizeof(struct ColorlessVertex)
                                  andPointer:(void*)(stepNumber * stepMallocSize + offsetof(struct ColorlessVertex, Size))];
        //        [context enableVertexArray];
        //        [context disableColorArray];
        //        [context enablePointSizeArray];
        //        [context disableTextureCoordArray];

        //        [context glColor4f:color[0] and:color[1] and:color[2] and:color[3]];
    }];
}

- (void)unbind {
    NSAssert(lock, @"must have a lock");
    [JotGLContext runBlock:^(JotGLContext* context) {
        [context unbindArrayBuffer];
    }];
    [lock unlock];
}

- (void)dealloc {
    [[JotBufferManager sharedInstance] openGLBufferHasDied:self];
    [[JotTrashManager sharedInstance] addObjectToDealloc:glBuffer];
    glBuffer = nil;
}


@end
