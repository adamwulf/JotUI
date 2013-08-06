//
//  JotBufferManager.m
//  JotUI
//
//  Created by Adam Wulf on 7/20/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotBufferManager.h"
#import "JotTrashManager.h"
#import "NSArray+JotMapReduce.h"
#import "JotUI.h"
#import "OpenGLVBO.h"

@implementation JotBufferManager{
    NSMutableDictionary* cacheOfVBOs;
    NSMutableDictionary* cacheStats;
}

static JotBufferManager* _instance = nil;

-(id) init{
    if(_instance) return _instance;
    if((self = [super init])){
        _instance = self;
        cacheOfVBOs = [NSMutableDictionary dictionary];
        cacheStats = [NSMutableDictionary dictionary];
        
#ifdef DEBUG
        if(kJotEnableCacheStats){
            dispatch_async(dispatch_get_main_queue(),^{
                [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(printStats) userInfo:nil repeats:YES];
                [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(resetCacheStats) userInfo:nil repeats:NO];
            });
        }
#endif
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
    return ceilf(vertexData.length / kJotBufferBucketSize);
}


-(JotBufferVBO*) bufferWithData:(NSData*)vertexData{
    NSInteger cacheNumberForData = [JotBufferManager cacheNumberForData:vertexData];
    NSMutableArray* vboCache = [self arrayOfVBOsForCacheNumber:cacheNumberForData];
    JotBufferVBO* buffer = [vboCache firstObject];
    NSMutableDictionary* stats = [cacheStats objectForKey:@(buffer.cacheNumber)];
    if(buffer){
        [vboCache removeObjectAtIndex:0];
        [buffer updateBufferWithData:vertexData];
        
        // update used stat
        int used = [[stats objectForKey:@"used"] intValue];
        [stats setObject:@(used + 1) forKey:@"used"];
    }else{
        // fill our cache with buffers of the right size
        OpenGLVBO* openGLVBO = [[OpenGLVBO alloc] initForCacheNumber:cacheNumberForData];
        for(int stepNumber=0;stepNumber<openGLVBO.numberOfSteps;stepNumber++){
            buffer = [[JotBufferVBO alloc] initWithData:vertexData andOpenGLVBO:openGLVBO andStepNumber:stepNumber];
            [vboCache addObject:buffer];
        }
        // now use the last of those newly created buffers
        buffer = [vboCache lastObject];
        [vboCache removeLastObject];
        
        // count miss
        int miss = [[stats objectForKey:@"miss"] intValue];
        [stats setObject:@(miss + 1) forKey:@"miss"];

        int mem = [[cacheStats objectForKey:@"totalMem"] intValue];
        mem += buffer.cacheNumber * kJotBufferBucketSize;
        [cacheStats setObject:@(mem) forKey:@"totalMem"];
    }
    int active = [[stats objectForKey:@"active"] intValue];
    [stats setObject:@(active + 1) forKey:@"active"];
    [self updateCacheStats];
    return buffer;
}

-(void) resetCacheStats{
    int mem = [[cacheStats objectForKey:@"totalMem"] intValue];
    [cacheStats removeAllObjects];
    [cacheStats setObject:@(mem) forKey:@"totalMem"];
    NSLog(@"RESET CACHE STATS!!!");
}

-(NSInteger) maxCacheSizeFor:(int)cacheNumber{
    if(cacheNumber <= 1){           // (.2k) * 1000 = 200k
        return 1000;
    }else if(cacheNumber <= 2){     // (.4k) * 1000 = 400k
        return 1000;
    }else if(cacheNumber <= 3){     // (.6k) * 1000 = 600k
        return 1000;
    }else if(cacheNumber <= 5){     // (.8k + 1.0k) * 5000 = 400 + 500 = 900k
        return 500;
    }else if(cacheNumber <= 7){     // (1.2k + 1.4k) * 20 = 240k + 280k = 520k
        return 20;
    }else if(cacheNumber <= 9){     // (1.6k + 1.8k) * 20 = 32k + 36k = 68k
        return 20;
    }else if(cacheNumber <= 12){    // (2.0k + 2.2k + 2.4k) * 20 = = 40 + 44 + 48k = 112k
        return 20;
    }else if(cacheNumber <= 15){    // (2.6k + 2.8k + 3.0k) * 20 = 52 + 56 + 60 = 168k
        return 20;
    }else{
        return 0;
    }
    
    // 200 + 400 + 600 + 900 + 520 + 68 + 112 + 168
    // 1200 + 1450 + 300
    // 2900
    // ~ 3Mb cache
}

-(void) recycleBuffer:(JotBufferVBO*)buffer{
    NSMutableArray* vboCache = [self arrayOfVBOsForCacheNumber:buffer.cacheNumber];
    if([vboCache count] >= [self maxCacheSizeFor:buffer.cacheNumber]){
        [[JotTrashManager sharedInstace] addObjectToDealloc:buffer];
        int mem = [[cacheStats objectForKey:@"totalMem"] intValue];
        mem -= buffer.cacheNumber * 2;
        [cacheStats setObject:@(mem) forKey:@"totalMem"];
        
        NSMutableDictionary* stats = [cacheStats objectForKey:@(buffer.cacheNumber)];
        int active = [[stats objectForKey:@"active"] intValue];
        [stats setObject:@(active - 1) forKey:@"active"];
    }else{
        [vboCache addObject:buffer];
    }
    [self updateCacheStats];
}

-(void) updateCacheStats{
#ifdef DEBUG
    if(kJotEnableCacheStats){
        for(id key in [cacheOfVBOs allKeys]){
            NSArray* vbos = [cacheOfVBOs objectForKey:key];
            NSMutableDictionary* stats = [cacheStats objectForKey:key];
            if(!stats){
                stats = [NSMutableDictionary dictionary];
                [cacheStats setObject:stats forKey:key];
            }
            double avg = [[stats objectForKey:@"avg"] doubleValue];
            avg = avg - avg / 100 + [vbos count] / 100.0;
            int max = [[stats objectForKey:@"max"] intValue];
            [stats setObject:@(avg) forKey:@"avg"];
            [stats setObject:@([vbos count]) forKey:@"current"];
            [stats setObject:@(MAX(max, [vbos count])) forKey:@"max"];
        }
    }
#endif
}


#pragma mark - Private

-(void) printStats{
#ifdef DEBUG
    if(kJotEnableCacheStats){
        NSLog(@"cache stats: %@", cacheStats);
    }
#endif
}

-(NSMutableArray*) arrayOfVBOsForCacheNumber:(int)size{
    NSMutableArray* arr = [cacheOfVBOs objectForKey:@(size)];
    if(!arr){
        arr = [NSMutableArray array];
        [cacheOfVBOs setObject:arr forKey:@(size)];
    }
    return arr;
}

@end
