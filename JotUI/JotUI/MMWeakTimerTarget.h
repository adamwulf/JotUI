//
//  MMWeakTimerTarget.h
//  JotUI
//
//  Created by Adam Wulf on 10/2/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MMWeakTimerTarget : NSObject

- (id)initWithTarget:(NSObject*)_target andSelector:(SEL)_selector;

- (void)timerDidFire:(NSTimer*)timer;

@end
