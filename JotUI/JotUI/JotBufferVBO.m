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
        // round up to nearest 2000 bytes
        mallocSize = ceilf(vertexData.length / 2000.0) * 2000;
        NSLog(@"malloc: %d %d", cacheNumber, mallocSize);
        glGenBuffers(1,&vbo);
        glBindBuffer(GL_ARRAY_BUFFER,vbo);
        // create buffer of size mallocSize (init w/ NULL to create)
        glBufferData(GL_ARRAY_BUFFER, mallocSize, NULL, GL_DYNAMIC_DRAW);
        // now fill with data
        glBufferSubData(GL_ARRAY_BUFFER, 0, vertexData.length, vertexData.bytes);
    }
    return self;
}

-(int) cacheNumber{
    return mallocSize / 2000;
}

-(void) updateBufferWithData:(NSData*)vertexData{
    if(vertexData.length > mallocSize){
        NSLog(@"too many bytes for this buffer!");
    }
    [self bind];
    glBufferSubData(GL_ARRAY_BUFFER, 0, vertexData.length, vertexData.bytes);
    NSLog(@"update: %d %d", cacheNumber, mallocSize);
}

-(void) bind{
    glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glVertexPointer(2, GL_FLOAT, sizeof(struct Vertex), offsetof(struct Vertex, Position));
    glColorPointer(4, GL_FLOAT, sizeof(struct Vertex), offsetof(struct Vertex, Color));
    glTexCoordPointer(2, GL_SHORT, sizeof(struct Vertex), offsetof(struct Vertex, Texture));
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
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
