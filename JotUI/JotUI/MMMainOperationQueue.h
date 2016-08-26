//
//  MMMainOperationQueue.h
//  JotUI
//
//  Created by Adam Wulf on 8/1/15.
//  Copyright (c) 2015 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface MMMainOperationQueue : NSOperationQueue

+ (MMMainOperationQueue*)sharedQueue;

- (void)addOperation:(NSOperation*)op NS_UNAVAILABLE;
- (void)addOperations:(NSArray*)ops waitUntilFinished:(BOOL)wait NS_AVAILABLE(10_6, 4_0)NS_UNAVAILABLE;

- (void)addOperationWithBlockAndWait:(void (^)(void))block;

- (NSUInteger)pendingBlockCount;
- (void)tick;
- (void)waitFor:(CGFloat)seconds;

@end
