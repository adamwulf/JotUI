//
//  MMWeakTimerTarget.m
//  JotUI
//
//  Created by Adam Wulf on 10/2/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import "MMWeakTimerTarget.h"


@implementation MMWeakTimerTarget {
    __weak NSObject* target;
    SEL selector;
}

- (id)initWithTarget:(NSObject*)_target andSelector:(SEL)_selector {
    if (self = [super init]) {
        target = _target;
        selector = _selector;
    }
    return self;
}

- (void)timerDidFire:(NSTimer*)timer {
    if (target) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:selector withObject:timer];
#pragma clang diagnostic pop
    } else {
        [timer invalidate];
    }
}

@end
