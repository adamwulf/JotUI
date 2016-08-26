//
//  JotBufferManager.m
//  JotUI
//
//  Created by Adam Wulf on 7/20/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import "JotBufferManager.h"
#import "JotTrashManager.h"
#import "NSArray+JotMapReduce.h"
#import "JotUI.h"
#import "OpenGLVBO.h"
#import "JotBufferVBO.h"
#import "MMMainOperationQueue.h"

/**
 * the JotBufferManager will help allocate
 * and manage VBOs that we can use when
 * creating stroke data.
 *
 * The premise:
 * When I'm asked for a buffer of size X,
 * If I have one available I'll just return it,
 * otherwise I'll create a buffer of size
 * X*Y. Then for the next Y requests of a buffer
 * I'll share that single buffer split at every
 * Y bytes.
 *
 * this way, i only allocate 1 time for Y buffer
 * requests. This'll save time, since I won't
 * need to constantly allocate and dealloc buffers.
 *
 * instead, I can create buffers of a consistent size,
 * creating multiple buffers at one time, reuse them
 * and only dealloc when all of them aren't in use any
 * more.
 *
 * There's a slight increase in memory footprint, since
 * some allocated memory isn't used, but the churn
 * for memory is greatly reduced, and CPU for allocations
 * is also dramatically reduced.
 */
@implementation JotBufferManager {
    // track an array of VBOs for various cache sizes
    NSMutableDictionary* cacheOfVBOs;
    // track cache stats in debug mode only
    NSMutableDictionary* cacheStats;
}

static JotBufferManager* _instance = nil;

- (id)init {
    if ((self = [super init])) {
        cacheOfVBOs = [NSMutableDictionary dictionary];
        cacheStats = [NSMutableDictionary dictionary];

#ifdef DEBUG
        if (kJotEnableCacheStats) {
            [[MMMainOperationQueue sharedQueue] addOperationWithBlock:^{
                @autoreleasepool {
                    [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(printStats) userInfo:nil repeats:YES];
                }
            }];
        }
#endif
    }
    return self;
}

- (NSDictionary*)cacheMemoryStats {
    @synchronized(cacheStats) {
        return [NSDictionary dictionaryWithDictionary:cacheStats];
    }
}

+ (JotBufferManager*)sharedInstance {
    if (!_instance) {
        _instance = [[JotBufferManager alloc] init];
    }
    return _instance;
}

/**
 * every VBO data will be allocated into a VBO
 * of at least that size, probably slightly larger.
 *
 * this cache number is used to track which size
 * buffer we need to hold all of its data.
 *
 * we'll cache and reuse multiple buffers according
 * to their cacheNumber, and how many we think we 
 * may need for that number
 */
+ (NSInteger)cacheNumberForData:(NSData*)vertexData {
    return ceilf(vertexData.length / kJotBufferBucketSize);
}


/**
 * input: any data for a VBO
 * output: a VBO object that we can use to bind/unbind/etc
 * that holds in the input data
 *
 * when possible, we reuse an empty buffer and fill it with
 * the input data. if we don't have a buffer available, then
 * we'll create a few of the input size, use 1, and have
 * some left over to use later if needed
 */
- (JotBufferVBO*)bufferWithData:(NSData*)vertexData {
    // first, figure out the cacheNumber, which we use to track which size buffer to use
    NSInteger cacheNumberForData = [JotBufferManager cacheNumberForData:vertexData];
    // look to see if/how many we have that are ready to use
    NSMutableArray* vboCache = [self arrayOfVBOsForCacheNumber:cacheNumberForData];
    JotBufferVBO* buffer = nil;
    @synchronized(vboCache) {
        buffer = [vboCache firstObject];
        if (buffer) {
            // if we have a buffer ready to use, then remove it from our cache,
            // update it's data, and return it
            [vboCache removeObjectAtIndex:0];
            [buffer updateBufferWithData:vertexData];
        } else {
            // we don't have any buffers of the size we need, so
            // fill our cache with buffers of the right size
            OpenGLVBO* openGLVBO = [[OpenGLVBO alloc] initForCacheNumber:cacheNumberForData];
            for (int stepNumber = 0; stepNumber < openGLVBO.numberOfSteps; stepNumber++) {
                buffer = [[JotBufferVBO alloc] initWithData:vertexData andOpenGLVBO:openGLVBO andStepNumber:stepNumber];
                [vboCache addObject:buffer];
            }
            // now use the last of those newly created buffers
            buffer = [vboCache lastObject];
            [vboCache removeLastObject];

            // stats:
            // track full memory size, and memory per cache number
            [[JotBufferManager sharedInstance] openGLBufferHasBeenBorn:openGLVBO];
        }
        //
        // track how many buffers are in use:

        [(JotGLContext*)[JotGLContext currentContext] setNeedsFlush:YES];
    }
    return buffer;
}

- (void)resetCacheStats {
    int mem = [[cacheStats objectForKey:kVBOCacheSize] intValue];
    [cacheStats removeAllObjects];
    [cacheStats setObject:@(mem) forKey:kVBOCacheSize];
}

/**
 * we don't want to blindly create tons of buffers and never
 * remove them from cache. we also don't want to remove all
 * our buffers from cache if we hit a low need time.
 *
 * this will return the number of buffers that we should keep
 * in cache for any given cacheNumber.
 *
 * anything above this will be automatically sent to the trashmanager
 * anything below will be kept.
 */
- (NSInteger)maxCacheSizeFor:(NSInteger)cacheNumber {
    int steps = [OpenGLVBO numberOfStepsForCacheNumber:cacheNumber];

    if (cacheNumber <= 1) {
        return steps * 10;
    } else if (cacheNumber <= 2) {
        return steps * 10;
    } else if (cacheNumber <= 3) {
        return steps * 10;
    } else if (cacheNumber <= 5) {
        return steps * 5;
    } else if (cacheNumber <= 7) {
        return steps * 2;
    } else if (cacheNumber <= 9) {
        return steps * 2;
    } else if (cacheNumber <= 12) {
        return steps * 2;
    } else if (cacheNumber <= 15) {
        return steps * 2;
    } else {
        return 0;
    }
}

/**
 * whoever was using the input buffer is done with it,
 * and doesn't need its contents anymore.
 *
 * this will decide if we have too many buffers of its size,
 * or if we should keep it in cache for later
 */
- (void)recycleBuffer:(JotBufferVBO*)buffer {
    NSMutableArray* vboCache = [self arrayOfVBOsForCacheNumber:buffer.cacheNumber];
    @synchronized(vboCache) {
        if ([vboCache count] >= [self maxCacheSizeFor:buffer.cacheNumber]) {
            JotBufferVBO* oldBuff = buffer;
            for (NSInteger i = 0; i < [vboCache count]; i++) {
                JotBufferVBO* buffInCache = [vboCache objectAtIndex:i];
                if (buffer.allocOrder < buffInCache.allocOrder) {
                    [vboCache replaceObjectAtIndex:i withObject:buffer];
                    buffer = buffInCache;
                }
            }
            if (oldBuff != buffer) {
                // throwing away buffer instead of oldBuff. we found a buffer that was
                // allocated later that we can throw away instead. this keeps the oldest
                // buffers in cache, and the youngest buffers are deallocated first
            }
            // we don't need this buffer anymore,
            // so send it off to the Trashmanager to dealloc
            [[JotTrashManager sharedInstance] addObjectToDealloc:buffer];
        } else {
            // we can still use this buffer later
            [vboCache addObject:buffer];
        }
    }
}

- (void)openGLBufferHasBeenBorn:(OpenGLVBO*)openGLVBO {
    @synchronized(cacheStats) {
        int mem = [[cacheStats objectForKey:kVBOCacheSize] intValue];
        mem += openGLVBO.fullByteSize;
        [cacheStats setObject:@(mem) forKey:kVBOCacheSize];

        NSString* cacheNumberKey = [NSString stringWithFormat:kVBOCacheNumSizeFmt, (int)openGLVBO.cacheNumber];
        mem = [[cacheStats objectForKey:cacheNumberKey] intValue];
        mem += openGLVBO.fullByteSize;
        [cacheStats setObject:@(mem) forKey:cacheNumberKey];
    }
}

- (void)openGLBufferHasDied:(OpenGLVBO*)openGLVBO {
    @synchronized(cacheStats) {
        int mem = [[cacheStats objectForKey:kVBOCacheSize] intValue];
        mem -= openGLVBO.fullByteSize;
        [cacheStats setObject:@(mem) forKey:kVBOCacheSize];

        NSString* cacheNumberKey = [NSString stringWithFormat:kVBOCacheNumSizeFmt, (int)openGLVBO.cacheNumber];
        mem = [[cacheStats objectForKey:cacheNumberKey] intValue];
        mem -= openGLVBO.fullByteSize;
        if (mem) {
            [cacheStats setObject:@(mem) forKey:cacheNumberKey];
        } else {
            [cacheStats removeObjectForKey:cacheNumberKey];
        }
    }
}

#pragma mark - Private

- (void)printStats {
#ifdef DEBUG
    if (kJotEnableCacheStats) {
        DebugLog(@"cache stats: %@", cacheStats);
    }
#endif
}

/**
 * this will return/create an array of VBOs for a
 * particular size
 */
- (NSMutableArray*)arrayOfVBOsForCacheNumber:(NSInteger)size {
    @synchronized(cacheOfVBOs) {
        NSMutableArray* arr = [cacheOfVBOs objectForKey:@(size)];
        if (!arr) {
            arr = [NSMutableArray array];
            [cacheOfVBOs setObject:arr forKey:@(size)];
        }
        return arr;
    }
}

@end
