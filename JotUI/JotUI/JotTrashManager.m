//
//  JotTrashManager.m
//  JotUI
//
//  Created by Adam Wulf on 6/19/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotTrashManager.h"
#import <QuartzCore/CAAnimation.h>

/**
 * The trash manager will hold onto objects and slowly
 * release them over time. This way, instead of releasing
 * many expensive objects at one moment, I'll release them
 * over time and spread that CPU over a longer duration.
 *
 * this'll prevent cpu spikes just from deallocs
 */
@implementation JotTrashManager{
    NSMutableArray* objectsToDealloc;
    NSTimeInterval maxTickDuration;
}

static JotTrashManager* _instance = nil;

-(id) init{
    if(_instance) return _instance;
    if((self = [super init])){
        objectsToDealloc = [[NSMutableArray alloc] init];
        maxTickDuration = 1;
        _instance = self;
    }
    return _instance;
}

+(JotTrashManager*) sharedInstace{
    if(!_instance){
        _instance = [[JotTrashManager alloc]init];
    }
    return _instance;
}


#pragma mark - Public Interface

/**
 * this will set the max amount of user time that
 * we'll spend on any given dealloc run
 *
 * this way, we can throttle deallocs so that we
 * can maintain 60fps
 */
-(void) setMaxTickDuration:(NSTimeInterval)_tickSize{
    maxTickDuration = _tickSize;
}

static int counter;

/**
 * release as many objects as we can within maxTickDuration
 *
 * for all objects we hold, we should be the only retain
 * for them, so releasing them will cause their dealloc
 */
-(BOOL) tick{
    double startTime = CACurrentMediaTime();
    int count = 0;
    while([objectsToDealloc count] && ABS(CACurrentMediaTime() - startTime) < maxTickDuration){
        @synchronized(self){
            [objectsToDealloc removeLastObject];
        }
        count++;
    }
    if(counter % 10 == 0){
        counter = 0;
    }
    counter++;
    return count > 0;
}

-(void) addObjectToDealloc:(NSObject*)obj{
    @synchronized(self){
        [objectsToDealloc addObject:obj];
    }
}


@end
