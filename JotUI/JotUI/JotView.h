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

@class JotViewImmutableState;

@class SegmentSmoother, UIPalmView;

@interface JotView : UIView<JotPalmRejectionDelegate,JotStrokeDelegate>

@property (nonatomic, weak) IBOutlet NSObject<JotViewDelegate>* delegate;
@property (nonatomic, strong) JotBrushTexture* brushTexture;
@property (readonly) EAGLContext *context;

// erase the screen
- (IBAction) clear;

// undo the last stroke, if possible
- (IBAction) undo;

// redo the last undo, if any
- (IBAction) redo;

// a unique value that defines the current undo state.
// if this value is the same as when this view was exported,
// then nothing has changed that would affect the output image
-(NSUInteger) undoHash;

// this will export both the ink and the thumbnail image
-(void) exportImageTo:(NSString*)inkPath
     andThumbnailTo:(NSString*)thumbnailPath
         andStateTo:(NSString*)plistPath
         onComplete:(void(^)(UIImage* ink, UIImage* thumb, JotViewImmutableState* state))exportFinishBlock;

// imports an image
-(void) loadImage:(NSString*)inkImageFile andState:(NSString*)stateInfoFile;

@end
