//
//  JotStrokeManager.m
//  JotUI
//
//  Created by Adam Wulf on 5/27/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotStrokeManager.h"




@interface JotStrokeManager ()
{
    
@private
    // this dictionary will hold all of the
    // stroke objects
    __strong NSMutableDictionary* strokeCache;
    __strong NSMutableDictionary* touchCache;
}

@end


@implementation JotStrokeManager


static JotStrokeManager* _instance = nil;

#pragma mark - Singleton

-(id) init{
    if(_instance) return _instance;
    if((self = [super init])){
        // noop
        strokeCache = [NSMutableDictionary dictionary];
        touchCache = [NSMutableDictionary dictionary];
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
    return [strokeCache objectForKey:@(touch.hash)];
}

-(JotStroke*) makeStrokeForTouchHash:(UITouch*)touch andTexture:(JotBrushTexture*)texture{
    JotStroke* ret = [strokeCache objectForKey:@(touch.hash)];
    if(!ret){
        ret = [[JotStroke alloc] initWithTexture:texture];
        [strokeCache setObject:ret forKey:@(touch.hash)];
        [touchCache setObject:@(touch.hash) forKey:@(ret.hash)];
    }
    return ret;
}

-(BOOL) cancelStrokeForTouch:(UITouch*)touch{
    //
    // TODO: how do we notify the view that uses the stroke
    // that it should be cancelled?
    JotStroke* stroke = [self getStrokeForTouchHash:touch];
    if(stroke){
        [stroke cancel];
        [self removeStrokeForTouch:touch];
    }
    return stroke != nil;
}

-(void) removeStrokeForTouch:(UITouch*)touch{
    [strokeCache removeObjectForKey:@(touch.hash)];
}

@end
