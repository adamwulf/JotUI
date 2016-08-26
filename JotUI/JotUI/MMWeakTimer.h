//
//  MMWeakTimer.h
//  JotUI
//
//  Created by Adam Wulf on 8/1/15.
//  Copyright (c) 2015 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MMWeakTimer : NSObject

- (id)init NS_UNAVAILABLE;

- (id)initScheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector;

- (void)invalidate;

- (void)fireIfNeeded;

+ (NSArray*)allWeakTimers;

@end
