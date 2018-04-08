//
//  JotViewState.m
//  JotUI
//
//  Created by Adam Wulf on 6/21/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import "JotViewState.h"
#import "JotImmutableStroke.h"
#import "NSArray+JotMapReduce.h"
#import "UIImage+Resize.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import "JotView.h"
#import "JotTrashManager.h"
#import "SegmentSmoother.h"
#import "AbstractBezierPathElement.h"
#import "AbstractBezierPathElement-Protected.h"
#import "NSMutableArray+RemoveSingle.h"
#import "JotDiskAssetManager.h"

#define kJotDefaultUndoLimit 10

//
// private intializer for the immutable state
@interface JotViewImmutableState ()

- (id)initWithDictionary:(NSDictionary*)stateInfo;

@end


@implementation JotViewState {
    // begin possible state object
    __strong JotGLTexture* backgroundTexture;
    __strong JotGLTextureBackedFrameBuffer* backgroundFramebuffer;
    __weak NSObject<JotStrokeDelegate>* delegate;

    // this dictionary will hold all of the in progress
    // stroke objects
    __strong JotStroke* currentStroke;
    // these arrays will act as stacks for our undo state
    __strong NSMutableArray* stackOfStrokes;
    __strong NSMutableArray* stackOfUndoneStrokes;
    NSMutableArray* strokesBeingWrittenToBackingTexture;
    JotBufferManager* bufferManager;

    CGSize fullPtSize;
    BOOL didRequireScaleDuringLoad;
}

@synthesize delegate;
@synthesize undoLimit;
@synthesize backgroundTexture;
@synthesize backgroundFramebuffer;
@synthesize currentStroke;
@synthesize bufferManager;
@synthesize strokesBeingWrittenToBackingTexture;

- (id)init {
    if (self = [super init]) {
        // setup our storage for our undo/redo strokes
        currentStroke = nil;
        stackOfStrokes = [NSMutableArray array];
        stackOfUndoneStrokes = [NSMutableArray array];
        strokesBeingWrittenToBackingTexture = [NSMutableArray array];
        undoLimit = kJotDefaultUndoLimit;
    }
    return self;
}

- (id)initWithImageFile:(NSString*)inkImageFile
           andStateFile:(NSString*)stateInfoFile
            andPageSize:(CGSize)_fullPtSize
               andScale:(CGFloat)scale
           andGLContext:(JotGLContext*)glContext
       andBufferManager:(JotBufferManager*)_bufferManager {
    if (self = [self init]) {
        bufferManager = _bufferManager;
        fullPtSize = _fullPtSize;
        // we're going to wait for two background operations to complete
        // using these semaphores
        dispatch_semaphore_t sema1 = dispatch_semaphore_create(0);
        dispatch_semaphore_t sema2 = dispatch_semaphore_create(0);


        // the second item is loading the ink texture
        // into Open GL
        dispatch_async([JotView importExportImageQueue], ^{
            @autoreleasepool {
                [self loadTextureHelperWithGLContext:glContext andInkImageFile:inkImageFile andPixelSize:CGSizeMake(fullPtSize.width * scale, fullPtSize.height * scale)];
                dispatch_semaphore_signal(sema1);
            }
        });

        // the first item is unserializing the plist
        // information for our page state
        dispatch_async([JotView importExportStateQueue], ^{
            @autoreleasepool {
                [self loadStrokesHelperWithGLContext:glContext andStateInfoFile:stateInfoFile andScale:scale];
                dispatch_semaphore_signal(sema2);
            }
        });
        // wait here
        // until both above items are complete
        dispatch_semaphore_wait(sema1, DISPATCH_TIME_FOREVER);
        dispatch_semaphore_wait(sema2, DISPATCH_TIME_FOREVER);
    }
    return self;
}

- (int)fullByteSize {
    int strokeTotal = 0;
    @synchronized(self) {
        NSArray* allStrokes;
        allStrokes = [NSArray arrayWithArray:stackOfStrokes];
        allStrokes = [allStrokes arrayByAddingObjectsFromArray:stackOfUndoneStrokes];
        allStrokes = [allStrokes arrayByAddingObjectsFromArray:strokesBeingWrittenToBackingTexture];
        for (JotStroke* stroke in allStrokes) {
            strokeTotal += stroke.fullByteSize;
        }
    }
    return backgroundTexture.fullByteSize + strokeTotal;
}

#pragma mark - Load Helpers

// These used to just be blocked used above in the initFromDictionary method,
// but I've moved them into methods so that instruments can give me better detail
// about CPU usage inside here

static JotGLContext* backgroundLoadTexturesThreadContext = nil;

- (void)loadTextureHelperWithGLContext:(JotGLContext*)glContext andInkImageFile:(NSString*)inkImageFile andPixelSize:(CGSize)fullPixelSize {
    if (![JotView isImportExportImageQueue]) {
        @throw [NSException exceptionWithName:@"InconsistentQueueException" reason:@"loading texture in wrong queue" userInfo:nil];
    }
    if (!backgroundLoadTexturesThreadContext) {
        backgroundLoadTexturesThreadContext = [[JotGLContext alloc] initWithName:@"JotBackgroundTextureLoadContext" andSharegroup:glContext.sharegroup andValidateThreadWith:^BOOL {
            return [JotView isImportExportImageQueue];
        }];
    }
    [backgroundLoadTexturesThreadContext runBlock:^{
        // load image from disk
        UIImage* savedInkImage = [JotDiskAssetManager imageWithContentsOfFile:inkImageFile];

        // load new texture
        self.backgroundTexture = [[JotGLTexture alloc] initForImage:savedInkImage withSize:fullPixelSize];

        if (!savedInkImage) {
            // no image was given, so it should be a blank texture
            // lets erase it, since it defaults to uncleared memory
            [self.backgroundFramebuffer clear];
        }
        [backgroundLoadTexturesThreadContext finish];
    }];
}

static JotGLContext* backgroundLoadStrokesThreadContext = nil;

- (void)loadStrokesHelperWithGLContext:(JotGLContext*)glContext andStateInfoFile:(NSString*)stateInfoFile andScale:(CGFloat)scale {
    if (![JotView isImportExportStateQueue]) {
        @throw [NSException exceptionWithName:@"InconsistentQueueException" reason:@"loading jotViewState in wrong queue" userInfo:nil];
    }
    if (!backgroundLoadStrokesThreadContext) {
        backgroundLoadStrokesThreadContext = [[JotGLContext alloc] initWithName:@"JotBackgroundStrokeLoadContext" andSharegroup:glContext.sharegroup andValidateThreadWith:^BOOL {
            return [JotView isImportExportStateQueue];
        }];
    }
    [backgroundLoadStrokesThreadContext runBlock:^{
        // load the file
        NSDictionary* stateInfo = [NSDictionary dictionaryWithContentsOfFile:stateInfoFile];

        undoLimit = [stateInfo[@"undoLimit"] integerValue] ?: kJotDefaultUndoLimit;

        if (stateInfo) {
            CGSize strokeStatePageSize = CGSizeMake([stateInfo[@"screenSize.width"] floatValue], [stateInfo[@"screenSize.height"] floatValue]);

            // load our undo state if we have it
            NSString* stateDirectory = [stateInfoFile stringByDeletingLastPathComponent];
            id (^loadStrokeBlock)(id obj, NSUInteger index) = ^id(id obj, NSUInteger index) {
                if (![obj isKindOfClass:[NSDictionary class]]) {
                    NSString* filename = [[stateDirectory stringByAppendingPathComponent:obj] stringByAppendingPathExtension:kJotStrokeFileExt];
                    obj = [NSDictionary dictionaryWithContentsOfFile:filename];
                }
                // pass in the buffer manager to use
                [obj setObject:bufferManager forKey:@"bufferManager"];
                [obj setObject:[NSNumber numberWithFloat:scale] forKey:@"scale"];

                NSString* className = [obj objectForKey:@"class"];
                Class class = NSClassFromString(className);
                JotStroke* stroke = [[class alloc] initFromDictionary:obj];

                if (!CGSizeEqualToSize(strokeStatePageSize, CGSizeZero)) {
                    if (fullPtSize.width != strokeStatePageSize.width && fullPtSize.height != strokeStatePageSize.height) {
                        didRequireScaleDuringLoad = YES;

                        CGFloat widthRatio = fullPtSize.width / strokeStatePageSize.width;
                        CGFloat heightRatio = fullPtSize.height / strokeStatePageSize.height;

                        [stroke scaleSegmentsForWidth:widthRatio andHeight:heightRatio];
                    }
                }

                stroke.delegate = self;
                return stroke;
            };

            @synchronized(self) {
                [stackOfStrokes addObjectsFromArray:[[stateInfo objectForKey:@"stackOfStrokes"] jotMap:loadStrokeBlock]];
                [stackOfUndoneStrokes addObjectsFromArray:[[stateInfo objectForKey:@"stackOfUndoneStrokes"] jotMap:loadStrokeBlock]];
            }
        }
        [backgroundLoadStrokesThreadContext finish];
    }];
}


#pragma mark - Public Methods

- (NSArray*)everyVisibleStroke {
    @synchronized(self) {
        if (self.currentStroke) {
            return [strokesBeingWrittenToBackingTexture arrayByAddingObjectsFromArray:[stackOfStrokes arrayByAddingObject:currentStroke]];
        }
        return [strokesBeingWrittenToBackingTexture arrayByAddingObjectsFromArray:stackOfStrokes];
    }
}


- (void)setBackgroundTexture:(JotGLTexture*)_backgroundTexture {
    // generate FBO for the texture
    backgroundTexture = _backgroundTexture;
    backgroundFramebuffer = [[JotGLTextureBackedFrameBuffer alloc] initForTexture:backgroundTexture];
}


- (void)tick {
    @synchronized(self) {
        if ([stackOfStrokes count] > undoLimit) {
            while ([stackOfStrokes count] > undoLimit) {
                [strokesBeingWrittenToBackingTexture addObject:[stackOfStrokes objectAtIndex:0]];
                [stackOfStrokes removeObjectAtIndex:0];
            }
        }
    }
}


- (JotViewImmutableState*)immutableState {
    if (![self isReadyToExport]) {
        @throw [NSException exceptionWithName:@"InvalidStateForExport" reason:@"the state is not ready to export, so it cannot generate an immutable state" userInfo:nil];
    }
    NSMutableDictionary* stateDict = [NSMutableDictionary dictionary];
    @synchronized(self) {
        [stateDict setObject:[stackOfStrokes copy] forKey:@"stackOfStrokes"];
        [stateDict setObject:[stackOfUndoneStrokes copy] forKey:@"stackOfUndoneStrokes"];
        // we need to also send in the hash value for our current undo state.
        // the ImmutableState object won't be able to calculate it, so we need to
        // send it in for it
        [stateDict setObject:[NSNumber numberWithUnsignedInteger:[self undoHash]] forKey:@"undoHash"];
        [stateDict setObject:[NSNumber numberWithInteger:[self undoLimit]] forKey:@"undoLimit"];

        stateDict[@"screenSize.width"] = @(fullPtSize.width);
        stateDict[@"screenSize.height"] = @(fullPtSize.height);
    }
    JotViewImmutableState* ret = [[JotViewImmutableState alloc] initWithDictionary:stateDict];

    ret.mustOverwriteAllStrokeFiles = didRequireScaleDuringLoad;

    return ret;
}

- (BOOL)isReadyToExport {
    [self tick];
    @synchronized(self) {
        if ([strokesBeingWrittenToBackingTexture count] ||
            currentStroke ||
            [stackOfStrokes count] > undoLimit) {
            if (currentStroke) {
                // can't save, currently drawing
            } else if ([strokesBeingWrittenToBackingTexture count]) {
                // can't save, writing to texture
            } else if ([stackOfStrokes count] > undoLimit) {
                // can't save, more strokes than our undo limit, waiting until they're written to texture
            }
            return NO;
        }
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
- (NSUInteger)undoHash {
    NSUInteger prime = 31;
    NSUInteger hashVal = 1;
    @synchronized(self) {
        for (JotStroke* stroke in stackOfStrokes) {
            hashVal = prime * hashVal + [stroke hash];
        }
        hashVal = prime * hashVal + 4409; // a prime from http://www.bigprimes.net/archive/prime/6/
        for (JotStroke* stroke in stackOfUndoneStrokes) {
            hashVal = prime * hashVal + [stroke hash];
        }
        hashVal = prime * hashVal + 4409; // a prime from http://www.bigprimes.net/archive/prime/6/
        if (self.currentStroke) {
            hashVal = prime * hashVal + [self.currentStroke hash];
        }
    }
    return hashVal;
}

#pragma mark - Undo Redo

- (BOOL)canUndo {
    @synchronized(self) {
        return [stackOfStrokes count] > 0;
    }
}

- (BOOL)canRedo {
    @synchronized(self) {
        return [stackOfUndoneStrokes count] > 0;
    }
}

- (JotStroke*)undo {
    @synchronized(self) {
        if ([self canUndo]) {
            JotStroke* undoneStroke = [stackOfStrokes lastObject];
            [stackOfUndoneStrokes addObject:undoneStroke];
            [stackOfStrokes removeLastObject];
            return undoneStroke;
        }
        return nil;
    }
}

- (JotStroke*)redo {
    @synchronized(self) {
        if ([self canRedo]) {
            JotStroke* redoneStroke = [stackOfUndoneStrokes lastObject];
            [stackOfStrokes addObject:redoneStroke];
            [stackOfUndoneStrokes removeLastObject];
            return redoneStroke;
        }
        return nil;
    }
}

- (JotStroke*)undoAndForget {
    @synchronized(self) {
        if ([self canUndo]) {
            JotStroke* lastKnownStroke = [stackOfStrokes lastObject];
            [stackOfStrokes removeLastObject];
            // don't add to the undone stack
            return lastKnownStroke;
        }
        return nil;
    }
}

- (void)forceAddStroke:(JotStroke*)stroke {
    @synchronized(self) {
        [stackOfStrokes addObject:stroke];
    }
}

- (void)finishCurrentStroke {
    @synchronized(self) {
        if (currentStroke) {
            [stackOfStrokes addObject:currentStroke];
            currentStroke = nil;
        }
        [[JotTrashManager sharedInstance] addObjectsToDealloc:stackOfUndoneStrokes];
        [stackOfUndoneStrokes removeAllObjects];
    }
}

- (void)addUndoLevelAndFinishStroke {
    @synchronized(self) {
        if (currentStroke) {
            [stackOfStrokes addObject:currentStroke];
            currentStroke = nil;
        } else {
            [self forceAddEmptyStrokeWithBrush:[JotDefaultBrushTexture sharedInstance]];
        }
        [[JotTrashManager sharedInstance] addObjectsToDealloc:stackOfUndoneStrokes];
        [stackOfUndoneStrokes removeAllObjects];
    }
}

- (void)forceAddEmptyStrokeWithBrush:(JotBrushTexture*)brushTexture {
    JotStroke* stroke = [[JotStroke alloc] initWithTexture:brushTexture andBufferManager:bufferManager];
    @synchronized(self) {
        [self forceAddStroke:stroke];
    }
}


- (void)clearAllStrokes {
    @synchronized(self) {
        [[JotTrashManager sharedInstance] addObjectsToDealloc:stackOfStrokes];
        [[JotTrashManager sharedInstance] addObjectsToDealloc:stackOfUndoneStrokes];
        [[JotTrashManager sharedInstance] addObjectToDealloc:currentStroke];
        [stackOfUndoneStrokes removeAllObjects];
        [stackOfStrokes removeAllObjects];
        currentStroke = nil;
    }
}

- (void)addUndoLevelAndContinueStroke {
    @synchronized(self) {
        if (currentStroke) {
            // we have a currentStroke, so we need to
            // make an empty stroke to pick up where this
            // one will leave off.
            [stackOfStrokes addObject:currentStroke];

            // now make a new stroke to pick up where we left off
            JotStroke* newStroke = [[JotStroke alloc] initWithTexture:currentStroke.texture andBufferManager:bufferManager];
            [newStroke.segmentSmoother copyStateFrom:currentStroke.segmentSmoother];
            // make sure it starts with the same size and color as where we ended
            MoveToPathElement* moveTo = [MoveToPathElement elementWithMoveTo:[[currentStroke.segments lastObject] endPoint]];
            moveTo.width = [(AbstractBezierPathElement*)[currentStroke.segments lastObject] width];
            moveTo.color = [(AbstractBezierPathElement*)[currentStroke.segments lastObject] color];
            moveTo.stepWidth = [(AbstractBezierPathElement*)[currentStroke.segments lastObject] stepWidth];
            moveTo.rotation = [(AbstractBezierPathElement*)[currentStroke.segments lastObject] rotation];
            [newStroke addElement:moveTo];

            // set it as our new current stroke
            JotStroke* oldCurrentStroke = currentStroke;
            currentStroke = newStroke;

            // update the stroke manager to make sure
            // it knows about the new stroke, and forgets
            // the old stroke
            [[JotStrokeManager sharedInstance] replaceStroke:oldCurrentStroke withStroke:newStroke];
        } else {
            // there is no current stroke, so just add an empty stroke
            // to our undo stack
            [self forceAddEmptyStrokeWithBrush:[JotDefaultBrushTexture sharedInstance]];
        }

        // since we've added an undo level, we need to
        // remove all undone strokes.
        [[JotTrashManager sharedInstance] addObjectsToDealloc:stackOfUndoneStrokes];
        [stackOfUndoneStrokes removeAllObjects];
    }
}


#pragma mark - JotStrokeDelegate

- (void)strokeWasCancelled:(JotStroke*)stroke {
    [delegate strokeWasCancelled:stroke];
}


#pragma mark - dealloc

- (void)dealloc {
    if (backgroundFramebuffer) {
        [[JotTrashManager sharedInstance] addObjectToDealloc:backgroundFramebuffer];
        backgroundFramebuffer = nil;
    }
    if (backgroundTexture) {
        [[JotTrashManager sharedInstance] addObjectToDealloc:backgroundTexture];
        backgroundTexture = nil;
    }
}

@end
