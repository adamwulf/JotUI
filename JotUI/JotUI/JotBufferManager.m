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
    NSMutableDictionary* cacheStats;
}

static JotBufferManager* _instance = nil;

-(id) init{
    if(_instance) return _instance;
    if((self = [super init])){
        _instance = self;
        cacheOfVBOs = [NSMutableDictionary dictionary];
        cacheStats = [NSMutableDictionary dictionary];
        
        dispatch_async(dispatch_get_main_queue(),^{
            [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(printStats) userInfo:nil repeats:YES];
            [NSTimer scheduledTimerWithTimeInterval:6 target:self selector:@selector(resetCacheStats) userInfo:nil repeats:NO];
        });
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
        
        // update used stat
        NSMutableDictionary* stats = [cacheStats objectForKey:@(buffer.cacheNumber)];
        int used = [[stats objectForKey:@"used"] intValue];
        [stats setObject:@(used + 1) forKey:@"used"];
    }else{
        buffer = [[JotBufferVBO alloc] initWithData:vertexData];
        // count miss
        NSMutableDictionary* stats = [cacheStats objectForKey:@(buffer.cacheNumber)];
        int miss = [[stats objectForKey:@"miss"] intValue];
        [stats setObject:@(miss + 1) forKey:@"miss"];
    }
    [self updateCacheStats];
    return buffer;
}

-(void) resetCacheStats{
    [cacheStats removeAllObjects];
    NSLog(@"RESET!!!");
}

-(NSInteger) maxCacheSizeFor:(int)cacheNumber{
    if(cacheNumber <= 1){           // (2k) * 300 = 0.6Mb
        return 300;
    }else if(cacheNumber <= 2){     // (4k) * 250 = 2Mb
        return 250;
    }else if(cacheNumber <= 5){     // (6k + 8k + 10k) * 200 = 4.8Mb
        return 200;
    }else if(cacheNumber <= 7){     // (12k 14k) * 150 = 3.9Mb
        return 150;
    }else if(cacheNumber <= 9){     // (16k + 18k) * 50 = 1.7Mb
        return 50;
    }else if(cacheNumber <= 12){    // (20k + 22k + 24k) * 20 = 1.3Mb
        return 20;
    }else if(cacheNumber <= 15){    // (26k + 28k + 30k) * 5 = .5Mb
        return 5;
    }else{
        return 0;
    }
    
//    ~15Mb cache
}

-(void) recycleBuffer:(JotBufferVBO*)buffer{
    NSMutableArray* vboCache = [self arrayOfVBOsForCacheNumber:buffer.cacheNumber];
    if([vboCache count] >= [self maxCacheSizeFor:buffer.cacheNumber]){
        [[JotTrashManager sharedInstace] addObjectToDealloc:buffer];
    }else{
        [vboCache addObject:buffer];
    }
    [self updateCacheStats];
}

-(void) updateCacheStats{
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



#pragma mark - Private

-(void) printStats{
    NSLog(@"cache stats: %@", cacheStats);
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
