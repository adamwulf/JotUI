//
//  JotViewState.h
//  JotUI
//
//  Created by Adam Wulf on 6/21/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotGLTexture.h"
#import "JotGLTextureBackedFrameBuffer.h"
#import "JotViewImmutableState.h"
#import "JotStrokeDelegate.h"
#import "JotGLContext.h"
#import "JotBufferManager.h"
#import "JotBrushTexture.h"

#define kJotStrokeFileExt @"strokedata"


@interface JotViewState : NSObject <JotStrokeDelegate>

// ability to cancel strokes
@property(nonatomic, weak) NSObject<JotStrokeDelegate>* delegate;
@property(nonatomic, assign) NSInteger undoLimit;

// backing textures
@property(nonatomic, strong) JotGLTexture* backgroundTexture;
@property(nonatomic, readonly) JotGLTextureBackedFrameBuffer* backgroundFramebuffer;
// backing strokes
@property(nonatomic, strong) JotStroke* currentStroke;
@property(nonatomic, readonly) NSMutableArray* strokesBeingWrittenToBackingTexture;
// opengl backing memory
@property(nonatomic, readonly) JotBufferManager* bufferManager;
@property(nonatomic, readonly) int fullByteSize;


/**
 * synchronous init method to load textures and strokes
 * from disk
 */
- (id)initWithImageFile:(NSString*)inkImageFile
           andStateFile:(NSString*)stateInfoFile
            andPageSize:(CGSize)fullPtSize
               andScale:(CGFloat)scale
           andGLContext:(JotGLContext*)glContext
       andBufferManager:(JotBufferManager*)bufferManager;

/**
 * this will return an immutable copy of the state
 * but only if we are ready to export
 *
 * otherwise it will throw an exception
 */
- (JotViewImmutableState*)immutableState;

/**
 * this will return YES only
 * if there are zero strokes in the 
 * strokesBeingWrittenToBackingTexture and
 * currentStrokes
 */
- (BOOL)isReadyToExport;

/**
 * this will return a combined array
 * of all of the strokesBeingWrittenToBackingTexture
 * stackOfStrokes, and currentStrokes
 * in the order that they should be visible
 */
- (NSArray*)everyVisibleStroke;

/**
 * this will check the state to make sure
 * there are less than the undoLimit of 
 * strokes in the stackOfStrokes, and will
 * move any to the strokesBeingWrittenToBackingTexture
 * that need to be
 */
- (void)tick;

/**
 * a unique value that defines the current undo state.
 * if this value is the same as when this view was exported,
 * then nothing has changed that would affect the output image
 */
- (NSUInteger)undoHash;


#pragma mark - Undo Redo

- (BOOL)canUndo;

- (BOOL)canRedo;

- (JotStroke*)undo;

- (JotStroke*)redo;

- (JotStroke*)undoAndForget;

- (void)finishCurrentStroke;

- (void)addUndoLevelAndFinishStroke;

- (void)addUndoLevelAndContinueStroke;

- (void)forceAddStroke:(JotStroke*)stroke;

- (void)forceAddEmptyStrokeWithBrush:(JotBrushTexture*)brushTexture;

- (void)clearAllStrokes;

@end
