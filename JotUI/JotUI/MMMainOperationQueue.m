//
//  MMMainOperationQueue.m
//  JotUI
//
//  Created by Adam Wulf on 8/1/15.
//  Copyright (c) 2015 Adonit. All rights reserved.
//

#import "MMMainOperationQueue.h"

@implementation MMMainOperationQueue{
    NSMutableArray* blockQueue;
    dispatch_semaphore_t sema;
}

static MMMainOperationQueue* sharedQueue;

+(MMMainOperationQueue*) sharedQueue{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedQueue = [[MMMainOperationQueue alloc] init];
    });
    return sharedQueue;
}

-(id) init{
    if(self = [super init]){
        blockQueue = [NSMutableArray array];
    }
    return self;
}

-(void) tick{
    @synchronized([MMMainOperationQueue class]){
        if([blockQueue count]){
            void(^block)() = [blockQueue firstObject];
            [blockQueue removeObjectAtIndex:0];
            block();
        }
    }
}

-(NSUInteger) pendingBlockCount{
    @synchronized([MMMainOperationQueue class]){
        return [blockQueue count];
    }
}

- (void)addOperationWithBlock:(void (^)(void))block NS_AVAILABLE(10_6, 4_0){
    @synchronized([MMMainOperationQueue class]){
        [blockQueue addObject:block];
        if(sema){
            dispatch_semaphore_signal(sema);
        }
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self tick];
    }];
}

-(void) waitFor:(CGFloat)seconds{
    @synchronized([MMMainOperationQueue class]){
        if(sema){
            dispatch_release(sema);
        }
        sema = dispatch_semaphore_create(0);
    }
    dispatch_time_t waitTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC));
    if(dispatch_semaphore_wait(sema, waitTime)){
        // noop, the sema has timed out
    }else{
        // noop, the sema was signaled
    }
}


@end
