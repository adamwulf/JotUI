//
//  MMDataCache.m
//  JotUI
//
//  Created by Adam Wulf on 12/11/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#import "MMDataCache.h"


@implementation MMDataCache {
    NSMutableArray* memoryQueue;
}

static MMDataCache* sharedCache;

+ (MMDataCache*)sharedCache {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCache = [[MMDataCache alloc] init];
    });
    return sharedCache;
}

- (instancetype)init {
    if (self = [super init]) {
        memoryQueue = [NSMutableArray array];
    }
    return self;
}

- (NSData*)dataOfSize:(NSUInteger)byteSize {
    NSData* cachedNSData = nil;

    @synchronized(memoryQueue) {
        for (NSData* data in memoryQueue) {
            if ([data length] >= byteSize) {
                cachedNSData = data;
                [memoryQueue removeObject:data];
                break;
            }
        }
    }

    if (!cachedNSData) {
        cachedNSData = [NSData dataWithBytesNoCopy:malloc(byteSize) length:byteSize freeWhenDone:NO];
    }

    return cachedNSData;
}

- (void)returnDataToCache:(NSData*)cachedNSData {
    @synchronized(memoryQueue) {
        [memoryQueue addObject:cachedNSData];
    }

    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(bleedCache) object:nil];
    [self performSelector:@selector(bleedCache) withObject:nil afterDelay:3];
}

- (void)bleedCache {
    @synchronized(memoryQueue) {
        if ([memoryQueue count]) {
            NSData* cachedNSData = [memoryQueue firstObject];
            [memoryQueue removeObjectAtIndex:0];
            free((void*)cachedNSData.bytes);

            // continue bleeding the cache every 3 seconds
            [self performSelector:@selector(bleedCache) withObject:nil afterDelay:3];
        }
    }
}

@end
