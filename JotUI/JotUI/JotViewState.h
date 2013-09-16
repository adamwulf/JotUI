//
//  JotViewState.h
//  JotUI
//
//  Created by Adam Wulf on 6/21/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotGLContext.h"
#import "JotGLTexture.h"
#import "JotGLTextureBackedFrameBuffer.h"
#import "JotViewImmutableState.h"
#import "JotStrokeDelegate.h"

@interface JotViewState : NSObject<JotStrokeDelegate>

//
// begin possible state object
@property (nonatomic, strong) JotGLTexture* backgroundTexture;
@property (nonatomic, weak) NSObject<JotStrokeDelegate>* delegate;
@property (nonatomic, readonly) JotGLTextureBackedFrameBuffer* backgroundFramebuffer;
@property (nonatomic, readonly)  NSMutableDictionary* currentStrokes;
@property (nonatomic, readonly)  NSMutableArray* stackOfStrokes;
@property (nonatomic, readonly)  NSMutableArray* stackOfUndoneStrokes;
@property (nonatomic, readonly) NSMutableArray* strokesBeingWrittenToBackingTexture;
@property (nonatomic) NSUInteger undoLimit;


-(id) initWithImageFile:(NSString*)inkImageFile
           andStateFile:(NSString*)stateInfoFile
            andPageSize:(CGSize)fullPixelSize
           andGLContext:(JotGLContext*)glContext;

/**
 * this will return YES only
 * if there are zero strokes in the 
 * strokesBeingWrittenToBackingTexture and
 * currentStrokes
 */
-(BOOL) isReadyToExport;

/**
 * this will return a combined array
 * of all of the strokesBeingWrittenToBackingTexture
 * stackOfStrokes, and currentStrokes
 * in the order that they should be visible
 */
-(NSArray*) everyVisibleStroke;

/**
 * this will check the state to make sure
 * there are less than the undoLimit of 
 * strokes in the stackOfStrokes, and will
 * move any to the strokesBeingWrittenToBackingTexture
 * that need to be
 */
-(void) tick;

/**
 * this will return an immutable copy of the state
 * but only if we are ready to export
 *
 * otherwise it will throw an exception
 */
-(JotViewImmutableState*) immutableState;

/**
 * a unique value that defines the current undo state.
 * if this value is the same as when this view was exported,
 * then nothing has changed that would affect the output image
 */
-(NSUInteger) undoHash;

@end
