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
#import "JotUI.h"

@implementation JotBufferVBO{
    int cacheNumber;
    OpenGLVBO* vbo;
    NSInteger stepNumber;
}


-(id) initWithData:(NSData*)vertexData andOpenGLVBO:(OpenGLVBO*)_vbo andStepNumber:(NSInteger)_stepNumber inContext:(JotGLContext*)context{
    if(self = [super init]){
        
        vbo = _vbo;
        stepNumber = _stepNumber;
        
        cacheNumber = [JotBufferManager cacheNumberForData:vertexData];

        [vbo updateStep:stepNumber withBufferWithData:vertexData inContext:context];
    }
    return self;
}

+(int) cacheNumberForBytes:(int)bytes{
    return ceilf(bytes / kJotBufferBucketSize);
}

-(int) cacheNumber{
    return cacheNumber;
}

-(void) updateBufferInContext:(JotGLContext*)context withData:(NSData*)vertexData{
    [vbo updateStep:stepNumber withBufferWithData:vertexData inContext:context];
}

-(void) bindToContext:(JotGLContext*)context{
    [vbo bindToContext:context forStep:stepNumber];
}

-(void) bindToContext:(JotGLContext*)context forColor:(UIColor*)color{
    [vbo bindToContext:context forColor:color andStep:stepNumber];
}

-(void) unbindFromContext:(JotGLContext*)context{
    [vbo unbindFromContext:context];
}



@end
