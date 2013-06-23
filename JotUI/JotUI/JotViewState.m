//
//  JotViewState.m
//  JotUI
//
//  Created by Adam Wulf on 6/21/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotViewState.h"
#import "JotImmutableStroke.h"

//
// private intializer for the immutable state
@interface JotViewImmutableState ()

-(id) initWithDictionary:(NSDictionary*)stateInfo;

@end


@implementation JotViewState{
    // begin possible state object
    __strong JotGLTexture* backgroundTexture;
    __strong JotGLTextureBackedFrameBuffer* backgroundFramebuffer;
    
    // this dictionary will hold all of the in progress
    // stroke objects
    __strong NSMutableDictionary* currentStrokes;
    // these arrays will act as stacks for our undo state
    __strong NSMutableArray* stackOfStrokes;
    __strong NSMutableArray* stackOfUndoneStrokes;
    NSMutableArray* strokesBeingWrittenToBackingTexture;
    NSUInteger undoLimit;
}

@synthesize backgroundTexture;
@synthesize backgroundFramebuffer;
@synthesize currentStrokes;
@synthesize stackOfStrokes;
@synthesize stackOfUndoneStrokes;
@synthesize strokesBeingWrittenToBackingTexture;
@synthesize undoLimit;

-(id) init{
    if(self = [super init]){
        // setup our storage for our undo/redo strokes
        currentStrokes = [NSMutableDictionary dictionary];
        stackOfStrokes = [NSMutableArray array];
        stackOfUndoneStrokes = [NSMutableArray array];
        strokesBeingWrittenToBackingTexture = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public Methods


-(NSArray*) everyVisibleStroke{
    return [self.strokesBeingWrittenToBackingTexture arrayByAddingObjectsFromArray:[self.stackOfStrokes arrayByAddingObjectsFromArray:[self.currentStrokes allValues]]];
}


-(void) setBackgroundTexture:(JotGLTexture *)_backgroundTexture{
    // generate FBO for the texture
    backgroundTexture = _backgroundTexture;
    backgroundFramebuffer = [[JotGLTextureBackedFrameBuffer alloc] initForTexture:backgroundTexture];
}


-(void) tick{
    if([self.stackOfStrokes count] > self.undoLimit){
        while([self.stackOfStrokes count] > self.undoLimit){
            NSLog(@"== eating strokes");
            
            [self.strokesBeingWrittenToBackingTexture addObject:[self.stackOfStrokes objectAtIndex:0]];
            [self.stackOfStrokes removeObjectAtIndex:0];
        }
    }
}


-(JotViewImmutableState*) immutableState{
    if(![self isReadyToExport]){
        @throw [NSException exceptionWithName:@"InvalidStateForExport" reason:@"the state is not ready to export, so it cannot generate an immutable state" userInfo:nil];
    }
    NSMutableDictionary* stateDict = [NSMutableDictionary dictionary];
    [stateDict setObject:[stackOfStrokes copy] forKey:@"stackOfStrokes"];
    [stateDict setObject:[stackOfUndoneStrokes copy] forKey:@"stackOfUndoneStrokes"];
    // we need to also send in the hash value for our current undo state.
    // the ImmutableState object won't be able to calculate it, so we need to
    // send it in for it
    [stateDict setObject:[NSNumber numberWithUnsignedInteger:[self undoHash]] forKey:@"undoHash"];

    return [[JotViewImmutableState alloc] initWithDictionary:stateDict];
}

-(BOOL) isReadyToExport{
    [self tick];
    if([strokesBeingWrittenToBackingTexture count] ||
       [currentStrokes count] ||
       [stackOfStrokes count] > undoLimit){
        if([currentStrokes count]){
            NSLog(@"cant save, currently drawing");
        }else if([strokesBeingWrittenToBackingTexture count]){
            NSLog(@"can't save, writing to texture");
        }else if([stackOfStrokes count] > undoLimit){
            NSLog(@"can't save, more strokes than undo");
        }
        return NO;
    }
    return YES;
}


/**
 * returns a single integer that represents the current state
 * of the visible UI. This number will take into account the strokes
 * that are in the undo stack, as well as any strokes that are
 * currenlty being drawn to the UI.
 *
 * any strokes in the redo stack are ignored. in this way, if the user
 * draws a stroke, then taps undo, the undoHash will be the same
 * as if they had never drawn the stroke
 */
-(NSUInteger) undoHash{
    NSUInteger hashVal = 0;
    for(JotStroke* stroke in self.stackOfStrokes){
        hashVal += [stroke hash];
    }
    for(JotStroke* stroke in self.currentStrokes){
        hashVal += [stroke hash];
    }
    return hashVal;
}

#pragma mark - dealloc

-(void)dealloc{
    backgroundFramebuffer = nil;
}

@end