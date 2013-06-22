//
//  JotViewState.h
//  JotUI
//
//  Created by Adam Wulf on 6/21/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotUI.h"
#import "JotGLTexture.h"
#import "JotGLTextureBackedFrameBuffer.h"
#import "JotViewImmutableState.h"

@interface JotViewState : NSObject

//
// begin possible state object
@property (nonatomic, strong) JotGLTexture* backgroundTexture;
@property (nonatomic, readonly) JotGLTextureBackedFrameBuffer* backgroundFramebuffer;
@property (nonatomic, readonly)  NSMutableDictionary* currentStrokes;
@property (nonatomic, readonly)  NSMutableArray* stackOfStrokes;
@property (nonatomic, readonly)  NSMutableArray* stackOfUndoneStrokes;
@property (nonatomic, readonly) NSMutableArray* strokesBeingWrittenToBackingTexture;
@property (nonatomic) NSUInteger undoLimit;

-(BOOL) isReadyToExport;
-(NSArray*) everyVisibleStroke;
-(void) tick;

-(JotViewImmutableState*) immutableState;

@end
