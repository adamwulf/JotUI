//
//  JotTrashManager.m
//  JotUI
//
//  Created by Adam Wulf on 6/19/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotTrashManager.h"
#import <QuartzCore/CAAnimation.h>
#import "JotGLTextureBackedFrameBuffer.h"

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
    JotGLContext* backgroundContext;
}

static dispatch_queue_t _trashQueue;
static JotTrashManager* _instance = nil;

+(dispatch_queue_t) trashQueue{
    if(!_trashQueue){
        _trashQueue = dispatch_queue_create("com.milestonemade.looseleaf.jotTrashQueue", DISPATCH_QUEUE_SERIAL);
    }
    return _trashQueue;
}

-(id) init{
    if(_instance) return _instance;
    if((self = [super init])){
        objectsToDealloc = [[NSMutableArray alloc] init];
        maxTickDuration = 1;
        _instance = self;
    }
    return _instance;
}

+(JotTrashManager*) sharedInstance{
    if(!_instance){
        _instance = [[JotTrashManager alloc] init];
    }
    return _instance;
}


#pragma mark - Public Interface

-(void) setGLContext:(JotGLContext*)context{
    dispatch_async([JotTrashManager trashQueue], ^{
        backgroundContext = [[JotGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:context.sharegroup];
    });
}

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

/**
 * release as many objects as we can within maxTickDuration
 *
 * for all objects we hold, we should be the only retain
 * for them, so releasing them will cause their dealloc
 */
-(BOOL) tick{
    if(!backgroundContext){
        // not ready to dealloc if we dont have a context yet
        return NO;
    }
    NSUInteger countToDealloc = 0;
    @synchronized(self){
        countToDealloc = [objectsToDealloc count];
    }
    if(countToDealloc){
        dispatch_async([JotTrashManager trashQueue], ^{
            @autoreleasepool {
                @synchronized(self){
                    if([objectsToDealloc count]){
                        if([JotGLContext currentContext] != backgroundContext){
                            [(JotGLContext*)[JotGLContext currentContext] flush];
                            [JotGLContext setCurrentContext:backgroundContext];
                        }
                        double startTime = CACurrentMediaTime();
                        while([objectsToDealloc count] && ABS(CACurrentMediaTime() - startTime) < maxTickDuration){
                            // this array should be the last retain for these objects,
                            // so removing them will release them and cause them to dealloc
                            [objectsToDealloc removeLastObject];
                        }
                    }
                }
            }
        });
    }
    return countToDealloc > 0;
}

-(void) addObjectToDealloc:(NSObject*)obj{
    @synchronized(self){
        [objectsToDealloc addObject:obj];
    }
}

#pragma mark - Profiling Helpers

-(NSInteger) numberOfItemsInTrash{
    @synchronized(self){
        return [objectsToDealloc count];
    }
}

-(int) knownBytesInTrash{
    NSArray* objs;
    @synchronized(self){
        if(objectsToDealloc){
            objs = [NSArray arrayWithArray:objectsToDealloc];
        }
    }
    int bytes = 0;
    for(NSObject*obj in objs){
        if([obj respondsToSelector:@selector(fullByteSize)]){
            bytes += (int) [obj performSelector:@selector(fullByteSize)];
        }
    }
    return bytes;
}

@end
