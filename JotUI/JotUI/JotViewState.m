//
//  JotViewState.m
//  JotUI
//
//  Created by Adam Wulf on 6/21/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotViewState.h"
#import "JotImmutableStroke.h"
#import "NSArray+JotMapReduce.h"
#import "UIImage+Resize.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "JotView.h"


#define kJotDefaultUndoLimit 10

//
// private intializer for the immutable state
@interface JotViewImmutableState ()

-(id) initWithDictionary:(NSDictionary*)stateInfo;

@end


@implementation JotViewState{
    // begin possible state object
    __strong JotGLTexture* backgroundTexture;
    __strong JotGLTextureBackedFrameBuffer* backgroundFramebuffer;
    __weak NSObject<JotStrokeDelegate>* delegate;
    
    // this dictionary will hold all of the in progress
    // stroke objects
    __strong NSMutableDictionary* currentStrokes;
    // these arrays will act as stacks for our undo state
    __strong NSMutableArray* stackOfStrokes;
    __strong NSMutableArray* stackOfUndoneStrokes;
    NSMutableArray* strokesBeingWrittenToBackingTexture;
    NSUInteger undoLimit;
}

@synthesize delegate;
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
        undoLimit = kJotDefaultUndoLimit;
    }
    return self;
}

-(id) initWithImageFile:(NSString*)inkImageFile
           andStateFile:(NSString*)stateInfoFile
            andPageSize:(CGSize)fullPixelSize
           andGLContext:(EAGLContext*)glContext{
    __block NSDictionary* stateInfo = nil;
    if(self = [self init]){
        // we're going to wait for two background operations to complete
        // using these semaphores
        dispatch_semaphore_t sema1 = dispatch_semaphore_create(0);
        dispatch_semaphore_t sema2 = dispatch_semaphore_create(0);
        
        
        // the second item is loading the ink texture
        // into Open GL
        dispatch_async([JotView importExportImageQueue], ^{
            NSDate* date = [NSDate date];
            
            EAGLContext* backgroundThreadContext = [[EAGLContext alloc] initWithAPI:glContext.API sharegroup:glContext.sharegroup];
            [EAGLContext setCurrentContext:backgroundThreadContext];
            
            // load image from disk
            UIImage* savedInkImage = [UIImage imageWithContentsOfFile:inkImageFile];
            
            // load new texture
            self.backgroundTexture = [[JotGLTexture alloc] initForImage:savedInkImage withSize:fullPixelSize];
            
            if(!savedInkImage){
                // no image was given, so it should be a blank texture
                // lets erase it, since it defaults to uncleared memory
                [self.backgroundFramebuffer clear];
            }
            glFlush();
            CGFloat duration = [[NSDate date] timeIntervalSinceDate:date];
            NSLog(@"bg load: %f", duration);
            dispatch_semaphore_signal(sema1);
        });
        
        // the first item is unserializing the plist
        // information for our page state
        dispatch_async([JotView importExportStateQueue], ^{
            NSDate* date = [NSDate date];
            EAGLContext* backgroundThreadContext = [[EAGLContext alloc] initWithAPI:glContext.API sharegroup:glContext.sharegroup];
            [EAGLContext setCurrentContext:backgroundThreadContext];

            // load the file
            stateInfo = [NSDictionary dictionaryWithContentsOfFile:stateInfoFile];
            
            if(stateInfo){
                // load our undo state if we have it
                id(^loadStrokeBlock)(id obj, NSUInteger index) = ^id(id obj, NSUInteger index){
                    NSString* className = [obj objectForKey:@"class"];
                    Class class = NSClassFromString(className);
                    JotStroke* stroke = [[class alloc] initFromDictionary:obj];
                    stroke.delegate = self;
                    return stroke;
                };
                
                [self.stackOfStrokes addObjectsFromArray:[[stateInfo objectForKey:@"stackOfStrokes"] jotMap:loadStrokeBlock]];
                [self.stackOfUndoneStrokes addObjectsFromArray:[[stateInfo objectForKey:@"stackOfUndoneStrokes"] jotMap:loadStrokeBlock]];
                
                //
                // sanity check
                for(JotStroke*stroke in [self.stackOfStrokes arrayByAddingObjectsFromArray:self.stackOfUndoneStrokes]){
                    if([stroke.segments count] == 0){
                        [self.stackOfStrokes removeObject:stroke];
                        [self.stackOfUndoneStrokes removeObject:stroke];
                        NSLog(@"oh no!");
                    }
                }
            }
            
            glFlush();
            CGFloat duration = [[NSDate date] timeIntervalSinceDate:date];
            NSLog(@"state load: %f", duration);
            dispatch_semaphore_wait(sema1, DISPATCH_TIME_FOREVER);
            dispatch_semaphore_signal(sema2);
        });
        // wait here
        // until both above items are complete
        dispatch_semaphore_wait(sema2, DISPATCH_TIME_FOREVER);
        
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
    NSUInteger prime = 31;
    NSUInteger hashVal = 1;
    for(JotStroke* stroke in self.stackOfStrokes){
        hashVal = prime * hashVal + [stroke hash];
    }
    for(JotStroke* stroke in self.currentStrokes){
        hashVal = prime * hashVal + [stroke hash];
    }
    return hashVal;
}


#pragma mark - JotStrokeDelegate

-(void) jotStrokeWasCancelled:(JotStroke*)stroke{
    [delegate jotStrokeWasCancelled:stroke];
}



#pragma mark - dealloc

-(void)dealloc{
    backgroundFramebuffer = nil;
}

@end