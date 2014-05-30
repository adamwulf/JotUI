//
//  JotTrashManager.h
//  JotUI
//
//  Created by Adam Wulf on 6/19/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotGLContext.h"

@interface JotTrashManager : NSObject

+(JotTrashManager*) sharedInstace;

-(void) setMaxTickDuration:(NSTimeInterval)tickSize;

-(BOOL) tick;

-(void) addObjectToDealloc:(NSObject*)obj;

-(NSInteger) numberOfItemsInTrash;

-(void) setGLContext:(JotGLContext*)context;

@end
