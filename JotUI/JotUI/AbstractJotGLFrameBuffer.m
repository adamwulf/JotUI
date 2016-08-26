//
//  AbstractJotGLFrameBuffer.m
//  JotUI
//
//  Created by Adam Wulf on 1/29/15.
//  Copyright (c) 2015 Milestone Made. All rights reserved.
//

#import "AbstractJotGLFrameBuffer.h"
#import "JotUI.h"


@implementation AbstractJotGLFrameBuffer {
    // lock to ensure we're only bound in once place
    NSRecursiveLock* lock;
}

- (id)init {
    if (self = [super init]) {
        // build a lock for this framebuffer
        lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (void)bind {
    [JotGLContext runBlock:^(JotGLContext* context) {
        [lock lock];
        [context bindFramebuffer:framebufferID];
    }];
}

- (void)unbind {
    [JotGLContext runBlock:^(JotGLContext* context) {
        [context unbindFramebuffer];
        [context flush];
        [lock unlock];
    }];
}

@end
