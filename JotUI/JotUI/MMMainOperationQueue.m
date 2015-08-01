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
    [blockQueue addObject:block];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self tick];
    }];
}



@end
