//
//  JotTrashManager.m
//  JotUI
//
//  Created by Adam Wulf on 6/19/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotTrashManager.h"

@implementation JotTrashManager{
    NSMutableArray* objectsToDealloc;
    NSTimeInterval maxTickDuration;
}

static JotTrashManager* _instance = nil;

-(id) init{
    if(_instance) return _instance;
    if((_instance = [super init])){
        objectsToDealloc = [[NSMutableArray alloc] init];
        maxTickDuration = 1;
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

-(void) setMaxTickDuration:(NSTimeInterval)_tickSize{
    maxTickDuration = _tickSize;
}

-(void) tick{
    NSDate *date = [NSDate date];
    int count = 0;
    while([objectsToDealloc count] && ABS([date timeIntervalSinceNow]) < maxTickDuration){
        [objectsToDealloc removeLastObject];
        count++;
    }
}

-(void) addObjectToDealloc:(NSObject*)obj{
    [objectsToDealloc addObject:obj];
}


@end
