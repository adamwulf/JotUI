//
//  MMWeakTimer.m
//  JotUI
//
//  Created by Adam Wulf on 8/1/15.
//  Copyright (c) 2015 Milestone Made. All rights reserved.
//

#import "MMWeakTimer.h"
#import "MMWeakTimerTarget.h"


@implementation MMWeakTimer {
    NSTimer* timer;
    MMWeakTimerTarget* weakTimerTarget;

    NSTimeInterval interval;
    NSTimeInterval lastTriggerTime;
}

static NSMutableArray* allWeakTimerArray;

+ (NSArray*)allWeakTimers {
    @synchronized([MMWeakTimer class]) {
        return [allWeakTimerArray copy];
    }
}

- (id)initScheduledTimerWithTimeInterval:(NSTimeInterval)_interval target:(id)aTarget selector:(SEL)aSelector {
    if (self = [super init]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            allWeakTimerArray = [[NSMutableArray alloc] init];
        });
        interval = _interval;
        weakTimerTarget = [[MMWeakTimerTarget alloc] initWithTarget:aTarget andSelector:aSelector];
        timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(timerDidFire:) userInfo:nil repeats:YES];
    }
    @synchronized([MMWeakTimer class]) {
        [allWeakTimerArray addObject:self];
    }

    return self;
}

- (void)invalidate {
    @synchronized([MMWeakTimer class]) {
        [allWeakTimerArray removeObject:self];
    }
    [timer invalidate];
    timer = nil;
    return;
}

- (void)timerDidFire:(NSTimer*)_timer {
    lastTriggerTime = CFAbsoluteTimeGetCurrent();
    [weakTimerTarget timerDidFire:_timer];
}

- (void)fireIfNeeded {
    if (timer) {
        if (CFAbsoluteTimeGetCurrent() - lastTriggerTime > interval) {
            [weakTimerTarget timerDidFire:timer];
        }
    }
}

@end
