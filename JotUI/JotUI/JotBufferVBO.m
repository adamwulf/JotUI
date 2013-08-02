//
//  JotBufferVBO.m
//  JotUI
//
//  Created by Adam Wulf on 7/20/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotBufferVBO.h"
#import "AbstractBezierPathElement.h"
#import "JotBufferManager.h"

@implementation JotBufferVBO{
    GLuint vbo;
    int mallocSize;
    int cacheNumber;
}


-(id) initWithData:(NSData*)vertexData{
    if(self = [super init]){
        cacheNumber = [JotBufferManager cacheNumberForData:vertexData];
        // round up to nearest kJotBufferBucketSize bytes
        mallocSize = ceilf(vertexData.length / kJotBufferBucketSize) * kJotBufferBucketSize;
        glGenBuffers(1,&vbo);
        glBindBuffer(GL_ARRAY_BUFFER,vbo);
        // create buffer of size mallocSize (init w/ NULL to create)
        glBufferData(GL_ARRAY_BUFFER, mallocSize, NULL, GL_DYNAMIC_DRAW);
        // now fill with data
        glBufferSubData(GL_ARRAY_BUFFER, 0, vertexData.length, vertexData.bytes);
    }
    return self;
}

+(int) cacheNumberForBytes:(int)bytes{
    return ceilf(bytes / kJotBufferBucketSize);
}

-(int) cacheNumber{
    return [JotBufferVBO cacheNumberForBytes:mallocSize];
}

-(void) updateBufferWithData:(NSData*)vertexData{
    [self bind];
    glBufferSubData(GL_ARRAY_BUFFER, 0, vertexData.length, vertexData.bytes);
}

-(void) bind{
    glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glVertexPointer(2, GL_FLOAT, sizeof(struct ColorfulVertex), offsetof(struct ColorfulVertex, Position));
    glColorPointer(4, GL_FLOAT, sizeof(struct ColorfulVertex), offsetof(struct ColorfulVertex, Color));
    glPointSizePointerOES(GL_FLOAT, sizeof(struct ColorfulVertex), offsetof(struct ColorfulVertex, Size));
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_POINT_SIZE_ARRAY_OES);
}

-(void) bindForColor:(UIColor*)color{
    glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glVertexPointer(2, GL_FLOAT, sizeof(struct ColorlessVertex), offsetof(struct ColorlessVertex, Position));
    glPointSizePointerOES(GL_FLOAT, sizeof(struct ColorlessVertex), offsetof(struct ColorlessVertex, Size));
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
