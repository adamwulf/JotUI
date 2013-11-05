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

dispatch_queue_t loadUnloadStateQueue;

@implementation JotViewStateProxy{
    // paths to save/load state
    NSString* inkPath;
    NSString* plistPath;

    // ideal state
    BOOL shouldKeepStateLoaded;
    BOOL isLoadingState;
    
    NSUInteger lastSavedUndoHash;
    JotViewState* jotViewState;
}

+(dispatch_queue_t) loadUnloadStateQueue{
    if(!loadUnloadStateQueue){
        loadUnloadStateQueue = dispatch_queue_create("com.milestonemade.looseleaf.loadUnloadStateQueue", DISPATCH_QUEUE_SERIAL);
    }
    return loadUnloadStateQueue;
}

@synthesize delegate;
@synthesize jotViewState;

-(id) initWithInkPath:(NSString*)_inkPath andPlistPath:(NSString*)_plistPath{
    if(self = [super init]){
        inkPath = _inkPath;
        plistPath = _plistPath;
    }
    return self;
}

-(void) loadStateAsynchronously:(BOOL)async withSize:(CGSize)pagePixelSize andContext:(JotGLContext*)context andBufferManager:(JotBufferManager*)bufferManager{
    @synchronized(self){
        // if we're already loading our
        // state, then bail early
        if(isLoadingState) return;
        // if we already have our state,
        // then bail early
        if(jotViewState) return;
        
        shouldKeepStateLoaded = YES;
        isLoadingState = YES;
    }

    void (^block2)() = ^(void) {
        @autoreleasepool {
            if(!jotViewState){
                jotViewState = [[JotViewState alloc] initWithImageFile:inkPath
                                                          andStateFile:plistPath
                                                           andPageSize:pagePixelSize
                                                          andGLContext:context
                                                      andBufferManager:bufferManager];
                lastSavedUndoHash = [jotViewState undoHash];
                @synchronized(self){
                    isLoadingState = NO;
                    if(shouldKeepStateLoaded){
                        // nothing changed in our goals since we started
                        // to load state, so notify our delegate
                        [self.delegate didLoadState:self];
                    }else{
                        // when loading state, we were actually
                        // told that we didn't really need the
                        // state after all, so just throw it away :(
                        jotViewState = nil;
                    }
                }
            }
        }
    };
    
    if(async){
        dispatch_async(([JotViewStateProxy loadUnloadStateQueue]), block2);
    }else{
        block2();
    }
}

-(void) wasSavedAtImmutableState:(JotViewImmutableState*)immutableState{
    lastSavedUndoHash = [immutableState undoHash];
}

-(void) unload{
    @synchronized(self){
        shouldKeepStateLoaded = NO;
        if([self hasEditsToSave]){
            NSLog(@"what??");
        }
        if(!isLoadingState && jotViewState){
            jotViewState = nil;
            [self.delegate didUnloadState:self];
        }
    }
}

-(BOOL) isStateLoaded{
    return jotViewState != nil;
}

-(BOOL) isReadyToExport{
    return [jotViewState isReadyToExport];
}

-(JotGLTexture*) backgroundTexture{
    return [jotViewState backgroundTexture];
}

-(NSArray*) everyVisibleStroke{
    return [jotViewState everyVisibleStroke];
}

-(void) tick{
    return [jotViewState tick];
}

-(NSMutableArray*) strokesBeingWrittenToBackingTexture{
    return [jotViewState strokesBeingWrittenToBackingTexture];
}

-(JotViewImmutableState*) immutableState{
    return [jotViewState immutableState];
}

-(JotBufferManager*) bufferManager{
    return [jotViewState bufferManager];
}

-(NSMutableDictionary*) currentStrokes{
    return [jotViewState currentStrokes];
}
-(NSMutableArray*) stackOfStrokes{
    return [jotViewState stackOfStrokes];
}
-(NSMutableArray*) stackOfUndoneStrokes{
    return [jotViewState stackOfUndoneStrokes];
}

-(JotGLTextureBackedFrameBuffer*) backgroundFramebuffer{
    return [jotViewState backgroundFramebuffer];
}

-(NSUInteger) undoHash{
    return [jotViewState undoHash];
}

/**
 * we have more information to save, if our
 * drawable view's hash does not equal to our
 * currently saved hash
 */
-(BOOL) hasEditsToSave{
    return [self.jotViewState undoHash] != lastSavedUndoHash;
}



-(void) dealloc{
    if([self hasEditsToSave]){
        NSLog(@"oh no %d", [self hasEditsToSave]);
    }
}

@end
