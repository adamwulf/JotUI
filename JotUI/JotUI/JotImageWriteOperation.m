//
//  JotImageWriteOperation.m
//  JotUI
//
//  Created by Adam Wulf on 10/30/14.
//  Copyright (c) 2014 Milestone Made. All rights reserved.
//

#import "JotImageWriteOperation.h"


@implementation JotImageWriteOperation {
    UIImage* imageToWrite;
    NSString* pathToWriteImageTo;
    void (^notifyBlock)(JotImageWriteOperation*);
    BOOL isRunning;
    NSObject* lock;
}

/** Initialize with the provided block. */
- (id)initWithImage:(UIImage*)image andPath:(NSString*)path andNotifyBlock:(void (^)(JotImageWriteOperation*))block {
    if ((self = [super init])) {
        pathToWriteImageTo = path;
        imageToWrite = image;
        notifyBlock = block;
        lock = [[NSObject alloc] init];
    }
    return self;
}

- (NSString*)path {
    return pathToWriteImageTo;
}

- (UIImage*)image {
    return imageToWrite;
}

// from NSOperation
- (void)main {
    @synchronized(lock) {
        if ([self isCancelled]) {
            if (notifyBlock) {
                notifyBlock(self);
            }
            return;
        } else {
            isRunning = YES;
        }
    }
    if (![self isCancelled]) {
        if (imageToWrite) {
            // if we have an image, then write it to disk
            [UIImagePNGRepresentation(imageToWrite) writeToFile:pathToWriteImageTo atomically:YES];
        } else {
            // otherwise, we don't have an image so delete anything off disk if needed
            [[NSFileManager defaultManager] removeItemAtPath:pathToWriteImageTo error:nil];
        }
    } else {
        // cancelled this operation, so we don't need to do anything at all
    }
    if (notifyBlock) {
        notifyBlock(self);
    }
}

- (void)cancel {
    @synchronized(lock) {
        if (!isRunning) {
            [super cancel];
        }
    }
}


@end
