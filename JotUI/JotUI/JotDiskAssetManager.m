//
//  JotDiskAssetManager.m
//  JotUI
//
//  Created by Adam Wulf on 10/29/14.
//  Copyright (c) 2014 Milestone Made. All rights reserved.
//

#import "JotDiskAssetManager.h"
#import "JotImageWriteOperation.h"


@implementation JotDiskAssetManager {
    NSMutableDictionary* inProcessDiskWrites;
    NSOperationQueue* opQueue;
}

#pragma mark - Queues

static dispatch_queue_t diskAssetQueue;
static const void* const kDiskAssetQueueIdentifier = &kDiskAssetQueueIdentifier;

+ (dispatch_queue_t)diskAssetQueue {
    if (!diskAssetQueue) {
        diskAssetQueue = dispatch_queue_create("com.milestonemade.looseleaf.diskAssetQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(diskAssetQueue, kDiskAssetQueueIdentifier, (void*)kDiskAssetQueueIdentifier, NULL);
    }
    return diskAssetQueue;
}

+ (BOOL)isDiskAssetQueue {
    return dispatch_get_specific(kDiskAssetQueueIdentifier) != NULL;
}

+ (UIImage*)imageWithContentsOfFile:(NSString*)path {
    return [[JotDiskAssetManager sharedManager] imageWithContentsOfFileHelper:path];
}

#pragma mark - Singleton

- (id)init {
    if (self = [super init]) {
        inProcessDiskWrites = [NSMutableDictionary dictionary];
        opQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

+ (JotDiskAssetManager*)sharedManager {
    static dispatch_once_t onceToken;
    static JotDiskAssetManager* manager;
    dispatch_once(&onceToken, ^{
        manager = [[[JotDiskAssetManager class] alloc] init];
    });
    return manager;
}


- (void)writeImage:(UIImage*)image toPath:(NSString*)path {
    JotImageWriteOperation* operation = nil;
    @synchronized(inProcessDiskWrites) {
        operation = [[JotImageWriteOperation alloc] initWithImage:image
                                                          andPath:path
                                                   andNotifyBlock:^(JotImageWriteOperation* operation) {
                                                       [self operationHasCompleted:operation];
                                                   }];

        JotImageWriteOperation* currOp = [self cancelAnyOperationFor:path];
        if (currOp) {
            [operation addDependency:currOp];
        }
        [inProcessDiskWrites setObject:operation forKey:path];
    }
    [opQueue addOperation:operation];
}

- (void)blockUntilCompletedForPath:(NSString*)path {
    if (path) {
        BOOL needsBlock = NO;
        @synchronized(inProcessDiskWrites) {
            needsBlock = [inProcessDiskWrites objectForKey:path] != nil;
        }
        if (needsBlock && opQueue.operationCount) {
            // blocking thread until we're done working
            [opQueue waitUntilAllOperationsAreFinished];
        }
    }
}

- (void)blockUntilCompletedForDirectory:(NSString*)dirPath {
    BOOL needsBlock = NO;
    if (dirPath) {
        @synchronized(inProcessDiskWrites) {
            needsBlock = [[[inProcessDiskWrites allKeys] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary* bindings) {
                return [evaluatedObject hasPrefix:dirPath];
            }]] count] > 0;
        }
        if (needsBlock && opQueue.operationCount) {
            // blocking thread until we're done working
            [opQueue waitUntilAllOperationsAreFinished];
        }
    }
}

- (void)blockUntilAllWritesHaveFinished {
    [opQueue waitUntilAllOperationsAreFinished];
}

#pragma mark - Notifications

- (void)operationHasCompleted:(JotImageWriteOperation*)operation {
    @synchronized(inProcessDiskWrites) {
        JotImageWriteOperation* currOpForPath = [inProcessDiskWrites objectForKey:operation.path];
        if (currOpForPath == operation) {
            [inProcessDiskWrites removeObjectForKey:operation.path];
        }
    }
}

- (JotImageWriteOperation*)cancelAnyOperationFor:(NSString*)path {
    JotImageWriteOperation* currentOperation = nil;
    @synchronized(inProcessDiskWrites) {
        if(path){
            currentOperation = [inProcessDiskWrites objectForKey:path];
            [inProcessDiskWrites removeObjectForKey:path];
        }
    }
    [currentOperation cancel];
    return currentOperation;
}

#pragma mark - Helper

- (UIImage*)imageWithContentsOfFileHelper:(NSString*)path {
    @synchronized(inProcessDiskWrites) {
        JotImageWriteOperation* operation = [inProcessDiskWrites objectForKey:path];
        if (operation) {
            return operation.image;
        }
    }
    return [UIImage imageWithContentsOfFile:path];
}


@end
