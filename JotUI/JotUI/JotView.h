//
//  Shortcut.h
//  JotSDKLibrary
//
//  Created by Adam Wulf on 11/19/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>

#import "JotUI/JotUI.h"
#import "JotUI/JotViewDelegate.h"
#import "JotUI/JotStroke.h"
#import "JotUI/JotGLTextureBackedFrameBuffer.h"
#import "JotUI/JotBrushTexture.h"
#import "JotUI/JotViewStateProxyDelegate.h"
#import "JotUI/JotViewState.h"
#import "JotUI/JotTextureCache.h"

#define kJotMaxStrokeByteSize 256 * 1024

@class JotViewImmutableState;

@class SegmentSmoother, UIPalmView;


@interface JotView : UIView <JotStrokeDelegate>

@property(readonly) JotViewStateProxy* state;
@property(nonatomic, weak) IBOutlet NSObject<JotViewDelegate>* delegate;
@property(readonly) JotGLContext* context;
@property(nonatomic) NSInteger maxStrokeSize;
// the pixel size of a page
@property(readonly) CGSize pagePtSize;
@property(readonly) CGFloat scale;


// erase the screen
- (IBAction)clear:(BOOL)shouldPresent;

- (BOOL)canUndo;
- (BOOL)canRedo;

// add an undo level. if there are no current strokes,
// then add an empty stroke to the stack. if there are
// current strokes, replace them with empty strokes and
// add them to the stack
- (void)addUndoLevelAndContinueStroke;

// undo the last stroke, if possible
- (IBAction)undo;

// undo and forget the last stroke, if possible. stroke cannot be redone.
- (void)undoAndForget;

// redo the last undo, if any
- (IBAction)redo;

// a unique value that defines the current undo state.
// if this value is the same as when this view was exported,
// then nothing has changed that would affect the output image
- (NSUInteger)undoHash;

// this will export both the ink and the thumbnail image
- (void)exportImageTo:(NSString*)inkPath
       andThumbnailTo:(NSString*)thumbnailPath
           andStateTo:(NSString*)plistPath
   withThumbnailScale:(CGFloat)thumbScale
           onComplete:(void (^)(UIImage* ink, UIImage* thumb, JotViewImmutableState* state))exportFinishBlock;

- (void)exportToImageOnComplete:(void (^)(UIImage*))exportFinishBlock withScale:(CGFloat)outputScale;

// imports an image
- (void)loadState:(JotViewStateProxy*)newState;

+ (dispatch_queue_t)importExportImageQueue;
+ (BOOL)isImportExportImageQueue;

+ (dispatch_queue_t)importExportStateQueue;
+ (BOOL)isImportExportStateQueue;

- (void)slowDownFPS;
- (void)speedUpFPS;
- (void)setPreferredFPS:(NSInteger)preferredFramesPerSecond;

- (NSInteger)maxCurrentStrokeByteSize;
- (void)addElements:(NSArray*)elements withTexture:(JotBrushTexture*)texture;
- (void)addUndoLevelAndFinishStroke;

- (void)forceAddEmptyStroke;
- (void)forceAddStrokeForFilledPath:(UIBezierPath*)path andP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4 andSize:(CGSize)size;

- (JotGLTexture*)generateTexture;
- (void)drawBackingTexture:(JotGLTexture*)texture atP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4 clippingPath:(UIBezierPath*)clipPath andClippingSize:(CGSize)clipSize withTextureSize:(CGSize)textureSize;

#pragma mark - debug
- (void)drawLongLine;

#pragma mark - jot trash

- (BOOL)hasLink;
- (void)invalidate;
- (void)deleteAssets;

@end
