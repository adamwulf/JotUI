//
//  Shortcut.h
//  JotSDKLibrary
//
//  Created by Adam Wulf on 11/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#import "JotUI/JotUI.h"
#import "JotUI/JotViewDelegate.h"
#import "JotUI/JotStroke.h"
#import "JotUI/JotGLTextureBackedFrameBuffer.h"
#import "JotUI/JotBrushTexture.h"
#import "JotUI/JotViewStateProxyDelegate.h"

@class JotViewImmutableState;

@class SegmentSmoother, UIPalmView;

@interface JotView : UIView<JotPalmRejectionDelegate,JotViewStateProxyDelegate>

@property (readonly) JotViewStateProxy* state;
@property (nonatomic, weak) IBOutlet NSObject<JotViewDelegate>* delegate;
@property (nonatomic, strong) JotBrushTexture* brushTexture;
@property (readonly) JotGLContext *context;
@property (nonatomic) NSInteger maxStrokeSize;

// erase the screen
- (IBAction) clear:(BOOL)shouldPresent;

-(BOOL) canUndo;
-(BOOL) canRedo;

// undo the last stroke, if possible
- (IBAction) undo;

// redo the last undo, if any
- (IBAction) redo;

// a unique value that defines the current undo state.
// if this value is the same as when this view was exported,
// then nothing has changed that would affect the output image
-(NSUInteger) undoHash;

// the pixel size of a page
-(CGSize) pagePixelSize;

// this will export both the ink and the thumbnail image
-(void) exportImageTo:(NSString*)inkPath
     andThumbnailTo:(NSString*)thumbnailPath
         andStateTo:(NSString*)plistPath
         onComplete:(void(^)(UIImage* ink, UIImage* thumb, JotViewImmutableState* state))exportFinishBlock;

// imports an image
-(void) loadState:(JotViewStateProxy*)newState;

+(dispatch_queue_t) importExportImageQueue;

+(dispatch_queue_t) importExportStateQueue;

-(void) slowDownFPS;
-(void) speedUpFPS;


-(void) addElements:(NSArray*)elements;
-(void) forceAddEmptyStroke;
-(void) forceAddStrokeForFilledPath:(UIBezierPath*)path andP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4;

-(JotGLTexture*) generateTexture;
-(void) drawBackingTexture:(JotGLTexture*)texture atP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4 clippingPath:(UIBezierPath*)clip;

#pragma mark - debug
-(void) drawLongLine;

@end
