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


-(id) initWithData:(NSData*)vertexData andOpenGLVBO:(OpenGLVBO*)_vbo andStepNumber:(NSInteger)_stepNumber{
    if(self = [super init]){
        
        vbo = _vbo;
        stepNumber = _stepNumber;
        
        cacheNumber = [JotBufferManager cacheNumberForData:vertexData];

        [vbo updateStep:stepNumber withBufferWithData:vertexData];
    }
    return self;
}

+(int) cacheNumberForBytes:(int)bytes{
    return ceilf(bytes / kJotBufferBucketSize);
}

-(int) cacheNumber{
    return cacheNumber;
}

-(void) updateBufferWithData:(NSData*)vertexData{
    [vbo updateStep:stepNumber withBufferWithData:vertexData];
}

-(void) bind{
    [vbo bindForStep:stepNumber];
}

-(void) bindForColor:(UIColor*)color{
    [vbo bindForColor:color andStep:stepNumber];
}

-(void) unbind{
    [vbo unbind];
}



@end
