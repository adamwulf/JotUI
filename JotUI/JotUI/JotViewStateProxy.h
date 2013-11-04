//
//  MMPaperState.h
//  LooseLeaf
//
//  Created by Adam Wulf on 9/24/13.
//  Copyright (c) 2013 Milestone Made, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JotUI/JotUI.h>
#import "JotViewStateProxyDelegate.h"

@class JotViewState;

@interface JotViewStateProxy : NSObject{
    __weak NSObject<JotViewStateProxyDelegate>* delegate;
}

+(dispatch_queue_t) loadUnloadStateQueue;

@property (nonatomic, weak) NSObject<JotViewStateProxyDelegate>* delegate;
@property (readonly) JotViewState* jotViewState;
@property (nonatomic, readonly) NSMutableArray* strokesBeingWrittenToBackingTexture;
@property (nonatomic, readonly) JotGLTextureBackedFrameBuffer* backgroundFramebuffer;
@property (nonatomic, readonly)  NSMutableDictionary* currentStrokes;
@property (nonatomic, readonly)  NSMutableArray* stackOfStrokes;
@property (nonatomic, readonly)  NSMutableArray* stackOfUndoneStrokes;

-(id) initWithInkPath:(NSString*)inkPath andPlistPath:(NSString*)plistPath;

-(BOOL) isStateLoaded;

-(BOOL) isReadyToExport;

-(JotViewImmutableState*) immutableState;

-(JotGLTexture*) backgroundTexture;

-(NSArray*) everyVisibleStroke;

-(JotBufferManager*) bufferManager;

-(void) tick;

-(NSUInteger) undoHash;

-(void) loadStateAsynchronously:(BOOL)async withSize:(CGSize)pagePixelSize andContext:(JotGLContext*)context andBufferManager:(JotBufferManager*)bufferManager;

-(void) unload;

-(BOOL) hasEditsToSave;

-(void) wasSavedAtImmutableState:(JotViewImmutableState*)immutableState;

@end
