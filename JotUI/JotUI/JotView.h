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

@class SegmentSmoother, UIPalmView;

@interface JotView : UIView<JotPalmRejectionDelegate>

@property (nonatomic, weak) IBOutlet NSObject<JotViewDelegate>* delegate;
@property (nonatomic) NSUInteger undoLimit;

// erase the screen
- (IBAction) clear;

// undo the last stroke, if possible
- (IBAction) undo;

// redo the last undo, if any
- (IBAction) redo;

// export the drawn strokes to a uiimage, with optional background color and background image
- (void) exportToImageWithBackgroundColor:(UIColor*)backgroundColor
                      andBackgroundImage:(UIImage*)backgroundImage
                              onComplete:(void(^)(UIImage*) )exportFinishBlock;

// imports an image
- (void) loadImage:(UIImage*)backgroundImage;

// set the image to use as the brush texture for the next strokes
- (void) setBrushTexture:(UIImage*)brushImage;

@end
