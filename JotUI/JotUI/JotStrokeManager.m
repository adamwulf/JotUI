//
//  JotStrokeManager.m
//  JotUI
//
//  Created by Adam Wulf on 5/27/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotStrokeManager.h"

@implementation JotStrokeManager


static JotStrokeManager* _instance = nil;

#pragma mark - Singleton

-(id) init{
    if(_instance) return _instance;
    if((_instance = [super init])){
        // noop
    }
    return _instance;
}

+(JotStrokeManager*) sharedInstace{
    if(!_instance){
        _instance = [[JotStrokeManager alloc]init];
    }
    return _instance;
}



@end
