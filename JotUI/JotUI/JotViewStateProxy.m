//
//  MMPaperState.m
//  LooseLeaf
//
//  Created by Adam Wulf on 9/24/13.
//  Copyright (c) 2013 Milestone Made, LLC. All rights reserved.
//

#import "JotViewStateProxy.h"
#import <JotUI/JotUI.h>
#import "JotViewState.h"

static dispatch_queue_t loadUnloadStateQueue;


@implementation JotViewStateProxy {
    // ideal state
    BOOL shouldKeepStateLoaded;
    BOOL isLoadingState;
    BOOL isForgetful;

    JotViewState* jotViewState;
}

+ (dispatch_queue_t)loadUnloadStateQueue {
    if (!loadUnloadStateQueue) {
        loadUnloadStateQueue = dispatch_queue_create("com.milestonemade.looseleaf.loadUnloadStateQueue", DISPATCH_QUEUE_SERIAL);
    }
    return loadUnloadStateQueue;
}

@synthesize delegate;
@synthesize jotViewState;
@synthesize isForgetful;

- (id)initWithDelegate:(NSObject<JotViewStateProxyDelegate>*)_delegate {
    if (self = [super init]) {
        self.delegate = _delegate;
    }
    return self;
}

- (int)fullByteSize {
    return jotViewState.fullByteSize;
}

- (NSMutableArray*)strokesBeingWrittenToBackingTexture {
    return jotViewState.strokesBeingWrittenToBackingTexture;
}

- (void)loadJotStateAsynchronously:(BOOL)async withSize:(CGSize)pagePtSize andScale:(CGFloat)scale andContext:(JotGLContext*)context andBufferManager:(JotBufferManager*)bufferManager {
    @synchronized(self) {
        // if we're already loading our
        // state, then bail early
        if (isLoadingState) {
            return;
        }
        // if we already have our state,
        // then bail early
        if (jotViewState) {
            return;
        }

        shouldKeepStateLoaded = YES;
        isLoadingState = YES;
    }

    void (^block2)(void) = ^(void) {
        @autoreleasepool {
            BOOL shouldLoadState = NO;
            @synchronized(self) {
                shouldLoadState = !jotViewState && shouldKeepStateLoaded;
            }

            if (shouldLoadState) {
                if (!shouldKeepStateLoaded) {
                    DebugLog(@"will waste some time loading a JotViewState that we don't need...");
                }
                jotViewState = [[JotViewState alloc] initWithImageFile:delegate.jotViewStateInkPath
                                                          andStateFile:delegate.jotViewStatePlistPath
                                                           andPageSize:pagePtSize
                                                              andScale:scale
                                                          andGLContext:context
                                                      andBufferManager:bufferManager];
                if (!shouldKeepStateLoaded) {
                    DebugLog(@"wasted some time loading a JotViewState that we didn't need...");
                }
                BOOL shouldNotify = NO;
                @synchronized(self) {
                    if (shouldKeepStateLoaded) {
                        lastSavedUndoHash = [jotViewState undoHash];
                        shouldNotify = YES;
                    } else {
                        shouldNotify = NO;
                        // when loading state, we were actually
                        // told that we didn't really need the
                        // state after all, so just throw it away :(
                    }
                }
                if (shouldNotify) {
                    // nothing changed in our goals since we started
                    // to load state, so notify our delegate
                    [self.delegate didLoadState:self];
                } else {
                    [[JotTrashManager sharedInstance] addObjectToDealloc:jotViewState];
                    @synchronized(self) {
                        jotViewState = nil;
                        lastSavedUndoHash = 0;
                    }
                }
                @synchronized(self) {
                    isLoadingState = NO;
                }
            } else if (!shouldKeepStateLoaded) {
                @synchronized(self) {
                    // saved an excess load
                    isLoadingState = NO;
                }
            } else {
                @synchronized(self) {
                    isLoadingState = NO;
                }
            }
        }
    };

    if (async) {
        dispatch_async(([JotViewStateProxy loadUnloadStateQueue]), block2);
    } else {
        block2();
    }
}

- (void)wasSavedAtImmutableState:(JotViewImmutableState*)immutableState {
    lastSavedUndoHash = [immutableState undoHash];
    lastSavedUndoHash = [immutableState undoHash];
}

- (void)unload {
    JotViewStateProxy* strongSelf = self;
    @synchronized(self) {
        shouldKeepStateLoaded = NO;
        if ([self isStateLoaded] && !isLoadingState) {
            dispatch_async(([JotViewStateProxy loadUnloadStateQueue]), ^{
                @autoreleasepool {
                    @synchronized(strongSelf) {
                        if ([self isStateLoaded]) {
                            shouldKeepStateLoaded = NO;
                            if (isLoadingState) {
                                // hrm, need to unload the state that
                                // never loaded in the first place.
                                // tell the state to immediately unload
                                // after it finishes
                                shouldKeepStateLoaded = NO;
                            } else if ([strongSelf hasEditsToSave]) {
                                @throw [NSException exceptionWithName:@"UnloadedEditedPageException" reason:@"The page has been asked to unload, but has edits pending save" userInfo:nil];
                            }
                            if (!isLoadingState && jotViewState) {
                                [[JotTrashManager sharedInstance] addObjectToDealloc:jotViewState];
                                jotViewState = nil;
                                lastSavedUndoHash = 0;
                                [strongSelf.delegate didUnloadState:strongSelf];
                            }
                        } else {
                            // noop, unloading a state proxy that's already unloaded
                        }
                    }
                }
            });
        } else {
            // saved an extra unload
        }
    }
}

- (BOOL)isStateLoaded {
    return jotViewState != nil;
}
- (BOOL)isStateLoading {
    return isLoadingState;
}

- (BOOL)isReadyToExport {
    return [jotViewState isReadyToExport];
}

- (JotGLTexture*)backgroundTexture {
    return [jotViewState backgroundTexture];
}

- (NSArray*)everyVisibleStroke {
    return [jotViewState everyVisibleStroke];
}

- (void)tick {
    return [jotViewState tick];
}

- (JotViewImmutableState*)immutableState {
    return [jotViewState immutableState];
}

- (JotBufferManager*)bufferManager {
    return [jotViewState bufferManager];
}

- (JotStroke*)currentStroke {
    return [jotViewState currentStroke];
}
- (void)setCurrentStroke:(JotStroke*)currentStroke {
    [jotViewState setCurrentStroke:currentStroke];
}

- (JotGLTextureBackedFrameBuffer*)backgroundFramebuffer {
    return [jotViewState backgroundFramebuffer];
}

- (NSUInteger)undoHash {
    return [jotViewState undoHash];
}

/**
 * we have more information to save, if our
 * drawable view's hash does not equal to our
 * currently saved hash
 */
- (BOOL)hasEditsToSave {
    if (self.isForgetful) {
        return NO;
    }
    return self.jotViewState && [self.jotViewState undoHash] != lastSavedUndoHash;
}

- (NSUInteger)currentStateUndoHash {
    return [self.jotViewState undoHash];
}
- (NSUInteger)lastSavedUndoHash {
    return lastSavedUndoHash;
}

#pragma mark - Undo Redo

- (BOOL)canUndo {
    return [self.jotViewState canUndo];
}

- (BOOL)canRedo {
    return [self.jotViewState canRedo];
}

- (JotStroke*)undo {
    return [self.jotViewState undo];
}

- (JotStroke*)redo {
    return [self.jotViewState redo];
}

- (JotStroke*)undoAndForget {
    return [self.jotViewState undoAndForget];
}

- (void)finishCurrentStroke {
    [self.jotViewState finishCurrentStroke];
}

- (void)forceAddStroke:(JotStroke*)stroke {
    [self.jotViewState forceAddStroke:stroke];
}

- (void)addUndoLevelAndFinishStroke {
    [self.jotViewState addUndoLevelAndFinishStroke];
}

- (void)forceAddEmptyStrokeWithBrush:(JotBrushTexture*)brushTexture {
    [self.jotViewState forceAddEmptyStrokeWithBrush:brushTexture];
}

- (void)clearAllStrokes {
    [self.jotViewState clearAllStrokes];
}

- (void)addUndoLevelAndContinueStroke {
    [self.jotViewState addUndoLevelAndContinueStroke];
}

- (NSInteger)undoLimit {
    return [jotViewState undoLimit];
}
- (void)setUndoLimit:(NSInteger)undoLimit {
    jotViewState.undoLimit = undoLimit;
}

#pragma mark - Dealloc

- (void)dealloc {
    NSAssert(![self hasEditsToSave], @"deallocating a jotview state that has pending edits");
}

@end
