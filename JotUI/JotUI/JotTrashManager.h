//
//  JotTrashManager.h
//  JotUI
//
//  Created by Adam Wulf on 6/19/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JotTrashManager : NSObject

+(JotTrashManager*) sharedInstace;

-(void) setMaxTickDuration:(NSTimeInterval)tickSize;

-(void) tick;

-(void) addObjectToDealloc:(NSObject*)obj;

@end
