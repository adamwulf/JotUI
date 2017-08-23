//
//  MMPaperState.h
//  LooseLeaf
//
//  Created by Adam Wulf on 9/24/13.
//  Copyright (c) 2013 Milestone Made, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotViewStateProxyDelegate.h"
#import "JotGLTextureBackedFrameBuffer.h"
#import "JotStroke.h"
#import "JotViewImmutableState.h"

@class JotViewState;


@interface JotViewStateProxy : NSObject {
    NSUInteger lastSavedUndoHash;
    __weak NSObject<JotViewStateProxyDelegate>* delegate;
}

@property(nonatomic, weak) NSObject<JotViewStateProxyDelegate>* delegate;
@property(readonly) JotViewState* jotViewState;
@property(nonatomic, readonly) NSMutableArray* strokesBeingWrittenToBackingTexture;
@property(nonatomic, readonly) JotGLTextureBackedFrameBuffer* backgroundFramebuffer;
@property(nonatomic, strong) JotStroke* currentStroke;
@property(nonatomic, readonly) int fullByteSize;
@property(nonatomic, assign) BOOL isForgetful;
@property(nonatomic, assign) NSInteger undoLimit;

- (id)initWithDelegate:(NSObject<JotViewStateProxyDelegate>*)delegate;

- (BOOL)isStateLoaded;
- (BOOL)isStateLoading;

- (BOOL)isReadyToExport;

- (JotViewImmutableState*)immutableState;

- (JotGLTexture*)backgroundTexture;

- (NSArray*)everyVisibleStroke;

- (JotBufferManager*)bufferManager;

- (void)tick;

- (NSUInteger)undoHash;

- (void)loadJotStateAsynchronously:(BOOL)async withSize:(CGSize)pagePtSize andScale:(CGFloat)scale andContext:(JotGLContext*)context andBufferManager:(JotBufferManager*)bufferManager;

- (void)unload;

- (BOOL)hasEditsToSave;

- (void)wasSavedAtImmutableState:(JotViewImmutableState*)immutableState;

#pragma mark - Undo Redo

- (BOOL)canUndo;

- (BOOL)canRedo;

- (JotStroke*)undo;

- (JotStroke*)redo;

// same as undo, except the undone
// stroke is not added to the redo stack
- (JotStroke*)undoAndForget;

// closes the current stroke and adds it to the
// undo stack
- (void)finishCurrentStroke;


- (void)addUndoLevelAndFinishStroke;

- (void)forceAddEmptyStrokeWithBrush:(JotBrushTexture*)brushTexture;

// adds the input stroke to the undo stack
// w/o clearing the undone strokes
- (void)forceAddStroke:(JotStroke*)stroke;

- (void)clearAllStrokes;

// returns the new stroke that is the continuation
// of the currentStroke
- (void)addUndoLevelAndContinueStroke;

#pragma mark - Debug

- (NSUInteger)currentStateUndoHash;
- (NSUInteger)lastSavedUndoHash;

@end
