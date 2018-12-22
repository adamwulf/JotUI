//
//  MMMainOperationQueue.m
//  JotUI
//
//  Created by Adam Wulf on 8/1/15.
//  Copyright (c) 2015 Milestone Made. All rights reserved.
//

#import "MMMainOperationQueue.h"
#import "JotUI.h"


@implementation MMMainOperationQueue {
    NSMutableArray* blockQueue;
    dispatch_semaphore_t sema;
}

static MMMainOperationQueue* sharedQueue;

+ (MMMainOperationQueue*)sharedQueue {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedQueue = [[MMMainOperationQueue alloc] init];
    });
    return sharedQueue;
}

- (id)init {
    if (self = [super init]) {
        blockQueue = [NSMutableArray array];
    }
    return self;
}

- (void)tick {
    CheckMainThread;
    void (^block)(void);
    @synchronized([MMMainOperationQueue class]) {
        if ([blockQueue count]) {
            block = [blockQueue firstObject];
            [blockQueue removeObjectAtIndex:0];
        }
    }
    if (block) {
        block();
    }
}

- (NSUInteger)pendingBlockCount {
    @synchronized([MMMainOperationQueue class]) {
        return [blockQueue count];
    }
}

- (void)addOperationWithBlockAndWait:(void (^)(void))block {
    if ([NSThread isMainThread]) {
        // if we're already on the main thread, then
        // just run the block
        block();
        return;
    }

    // create a semaphore that we'll use to wait
    // until the block executes
    dispatch_semaphore_t localSema = dispatch_semaphore_create(0);

    // create a new block that will signal
    // when it's complete
    void (^waitingBlock)(void) = ^{
        block();
        dispatch_semaphore_signal(localSema);
    };

    // add the bock to the queue
    @synchronized([MMMainOperationQueue class]) {
        [blockQueue addObject:waitingBlock];
        if (sema) {
            dispatch_semaphore_signal(sema);
        }
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self tick];
    }];

    // and now wait until it's complete
    dispatch_semaphore_wait(localSema, DISPATCH_TIME_FOREVER);
}

- (void)addOperationWithBlock:(void (^)(void))block NS_AVAILABLE(10_6, 4_0) {
    @synchronized([MMMainOperationQueue class]) {
        [blockQueue addObject:block];
        if (sema) {
            dispatch_semaphore_signal(sema);
        }
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self tick];
    }];
}

- (void)waitFor:(CGFloat)seconds {
    @synchronized([MMMainOperationQueue class]) {
        sema = dispatch_semaphore_create(0);
    }
    dispatch_time_t waitTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC));
    if (dispatch_semaphore_wait(sema, waitTime)) {
        // noop, the sema has timed out
    } else {
        // noop, the sema was signaled
    }
}


@end
