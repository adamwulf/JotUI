//
//  JotBufferManager.m
//  JotUI
//
//  Created by Adam Wulf on 7/20/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotBufferManager.h"
#import "JotTrashManager.h"

@implementation JotBufferManager{
    NSMutableDictionary* cacheOfVBOs;
}

static JotBufferManager* _instance = nil;

-(id) init{
    if(_instance) return _instance;
    if((self = [super init])){
        _instance = self;
        cacheOfVBOs = [NSMutableDictionary dictionary];
    }
    return _instance;
}

+(JotBufferManager*) sharedInstace{
    if(!_instance){
        _instance = [[JotBufferManager alloc]init];
    }
    return _instance;
}

+(NSInteger) cacheNumberForData:(NSData *)vertexData{
    return ceilf(vertexData.length / 2000.0);
}


-(JotBufferVBO*) bufferWithData:(NSData*)vertexData{
    NSMutableArray* arr = [self arrayOfVBOsForCacheNumber:[JotBufferManager cacheNumberForData:vertexData]];
    JotBufferVBO* buffer = [arr firstObject];
    if(buffer){
        [arr removeObjectAtIndex:0];
        [buffer updateBufferWithData:vertexData];
        return buffer;
    }else{
        return [[JotBufferVBO alloc] initWithData:vertexData];
    }
}

-(void) recycleBuffer:(JotBufferVBO*)buffer{
    [[self arrayOfVBOsForCacheNumber:buffer.cacheNumber] addObject:buffer];
//    [[JotTrashManager sharedInstace] addObjectToDealloc:buffer];
}



#pragma mark - Private

-(NSMutableArray*) arrayOfVBOsForCacheNumber:(int)size{
    NSMutableArray* arr = [cacheOfVBOs objectForKey:@(size)];
    if(!arr){
        arr = [NSMutableArray array];
        [cacheOfVBOs setObject:arr forKey:@(size)];
    }
    return arr;
}

@end
