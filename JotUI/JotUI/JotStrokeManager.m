//
//  JotStrokeManager.m
//  JotUI
//
//  Created by Adam Wulf on 5/27/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotStrokeManager.h"


#define kMaxSimultaneousTouchesAllowedToTrack 40

struct TouchStrokeCacheItem{
    NSUInteger touchHash;
    JotStroke* stroke;
};


@interface JotStrokeManager ()
{
    
@private
    // this dictionary will hold all of the
    // stroke objects
    struct TouchStrokeCacheItem strokeCache[kMaxSimultaneousTouchesAllowedToTrack];
}

@end


@implementation JotStrokeManager


static JotStrokeManager* _instance = nil;

#pragma mark - Singleton

-(id) init{
    if(_instance) return _instance;
    if((self = [super init])){
        // noop
        _instance = self;
    }
    return _instance;
}

+(JotStrokeManager*) sharedInstace{
    if(!_instance){
        _instance = [[JotStrokeManager alloc]init];
    }
    return _instance;
}

#pragma mark - Cache Methods


/**
 * it's possible to have multiple touches on the screen
 * generating multiple current in-progress strokes
 *
 * this method will return the stroke for the given touch
 */
-(JotStroke*) getStrokeForTouchHash:(UITouch*)touch{
    for(int i=0;i<kMaxSimultaneousTouchesAllowedToTrack;i++){
        if(strokeCache[i].touchHash == touch.hash){
            return strokeCache[i].stroke;
        }
    }
    return nil;
}

-(JotStroke*) makeStrokeForTouchHash:(UITouch*)touch andTexture:(JotBrushTexture*)texture{
    JotStroke* ret = [self getStrokeForTouchHash:touch];
    if(!ret){
        ret = [[JotStroke alloc] initWithTexture:texture];
        for(int i=0;i<kMaxSimultaneousTouchesAllowedToTrack;i++){
            if(strokeCache[i].touchHash == 0){
                strokeCache[i].touchHash = touch.hash;
                strokeCache[i].stroke = ret;
                return ret;
            }
        }
    }
    return ret;
}

-(BOOL) cancelStrokeForTouch:(UITouch*)touch{
    //
    // TODO: how do we notify the view that uses the stroke
    // that it should be cancelled?
    for(int i=0;i<kMaxSimultaneousTouchesAllowedToTrack;i++){
        if(strokeCache[i].touchHash == touch.hash){
            strokeCache[i].touchHash = 0;
            [strokeCache[i].stroke cancel];
            [strokeCache[i].stroke autorelease];
            return YES;
        }
    }
    return NO;
}

-(void) removeStrokeForTouch:(UITouch*)touch{
    for(int i=0;i<kMaxSimultaneousTouchesAllowedToTrack;i++){
        if(strokeCache[i].touchHash == touch.hash){
            strokeCache[i].touchHash = 0;
            [strokeCache[i].stroke autorelease];
            return;
        }
    }
}

@end
