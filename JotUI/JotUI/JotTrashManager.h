//
//  JotTrashManager.h
//  JotUI
//
//  Created by Adam Wulf on 6/19/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotGLContext.h"


@interface JotTrashManager : NSObject

+ (JotTrashManager*)sharedInstance;

+ (BOOL)isTrashManagerQueue;

- (void)setMaxTickDuration:(NSTimeInterval)tickSize;

- (BOOL)tick;

- (void)addObjectToDealloc:(NSObject*)obj;

- (void)addObjectsToDealloc:(NSArray*)objs;

- (void)setGLContext:(JotGLContext*)context;

- (NSInteger)numberOfItemsInTrash;

- (int)knownBytesInTrash;

@end
