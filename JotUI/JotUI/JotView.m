//
//  Shortcut.h
//  JotSDKLibrary
//
//  Created by Adam Wulf on 11/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <mach/mach_time.h>  // for mach_absolute_time() and friends

#import "JotView.h"
#import "JotStrokeManager.h"
#import "AbstractBezierPathElement.h"
#import "AbstractBezierPathElement-Protected.h"
#import "CurveToPathElement.h"
#import "UIColor+JotHelper.h"
#import "JotGLTexture.h"
#import "JotGLTextureBackedFrameBuffer.h"
#import "JotDefaultBrushTexture.h"
#import "JotTrashManager.h"
#import "JotViewState.h"
#import "JotViewImmutableState.h"
#import "SegmentSmoother.h"
#import "JotFilledPathStroke.h"
#import "MMWeakTimerTarget.h"
#import "JotTextureCache.h"
#import "NSMutableArray+RemoveSingle.h"
#import "JotDiskAssetManager.h"
#import <JotTouchSDK/JotStylusManager.h>
#import "JotGLLayerBackedFrameBuffer.h"
#import "UIScreen+PortraitBounds.h"

#define kJotValidateUndoTimer .06


dispatch_queue_t importExportImageQueue;
dispatch_queue_t importExportStateQueue;


@interface JotView (){
    __weak NSObject<JotViewDelegate>* delegate;
    
	JotGLContext *context;
    
@private
    JotGLLayerBackedFrameBuffer* viewFramebuffer;

    //
    // these 4 properties help with our performance when writing
    // large strokes to the backing texture. the timer will continually
    // try to validate our undo state. if a stroke needs to be pushed
    // off the undo stack, then it's added to the strokesBeingWrittenToBackingTexture
    // array, and then progressively written to the backing texture over
    // numerous calls by the Timer.
    //
    // this prevents an entire stroke from being written to the texture
    // in just 1 go, and spreads that work out over time.
    //
    // if our export method gets called while we're writing to the texture,
    // then we add that to a queue and will re-call that export method
    // after all the strokes have been written to disk
    NSTimer* validateUndoStateTimer;
    AbstractBezierPathElement* prevElementForTextureWriting;
    NSMutableArray* exportLaterInvocations;
    NSUInteger isCurrentlyExporting;

    // a handle to the image used as the current brush texture
    JotViewStateProxy* state;
    
    CGSize initialFrameSize;
    
    // the maximum stroke size in bytes before a new stroke
    // is created
    NSInteger maxStrokeSize;
    
    NSLock* inkTextureLock;
    NSLock* imageTextureLock;
}

@end


@implementation JotView

@synthesize delegate;
@synthesize context;
@synthesize maxStrokeSize;
@synthesize state;

#pragma mark - Initialization

static JotGLContext *mainThreadContext;

+(JotGLContext*) mainThreadContext{
    return mainThreadContext;
}

/**
 * Implement this to override the default layer class (which is [CALayer class]).
 * We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
 */
+ (Class) layerClass{
	return [CAEAGLLayer class];
}

/**
 * The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
 */
- (id)initWithCoder:(NSCoder*)coder {
    if ((self = [super initWithCoder:coder])) {
        return [self finishInit];
		
	}
	return self;
}

/**
 * initialize a new view for the given frame
 */
- (id) initWithFrame:(CGRect)frame{
    frame.size.width = ceilf(frame.size.width);
    frame.size.height = ceilf(frame.size.height);
    if((self = [super initWithFrame:frame])){
        return [self finishInit];
    }
    return self;
}

-(id) finishInit{
    CheckMainThread;
    inkTextureLock = [[NSLock alloc] init];
    imageTextureLock = [[NSLock alloc] init];
    // strokes have a max of .5Mb each
    self.maxStrokeSize = 512*1024;
    
    CADisplayLink* displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkPresentRenderBuffer:)];
    displayLink.frameInterval = 2;
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

    initialFrameSize = self.bounds.size;
    
    prevElementForTextureWriting = nil;
    exportLaterInvocations = [NSMutableArray array];
    
    MMWeakTimerTarget* weakTimerTarget = [[MMWeakTimerTarget alloc] initWithTarget:self andSelector:@selector(validateUndoState:)];
    
    validateUndoStateTimer = [NSTimer scheduledTimerWithTimeInterval:kJotValidateUndoTimer
                                                              target:weakTimerTarget
                                                            selector:@selector(timerDidFire:)
                                                            userInfo:nil
                                                             repeats:YES];

    //
    // this view should accept Jot stylus touch events
    [[JotTrashManager sharedInstance] setMaxTickDuration:kJotValidateUndoTimer * 1 / 20];

    // create a default empty state
    state = nil;
    
    // allow more than 1 finger/stylus to draw at a time
    self.multipleTouchEnabled = YES;
    
    //
    // the remainder is OpenGL initialization
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = NO;
    // In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    if(!mainThreadContext){
        context = [[JotGLContext alloc] initWithName:@"JotViewMainThreadContext" andAPI:kEAGLRenderingAPIOpenGLES1 andValidateThreadWith:^BOOL{
            return [NSThread isMainThread];
        }];
        mainThreadContext = context;
        [[JotTrashManager sharedInstance] setGLContext:mainThreadContext];
    }else{
        context = [[JotGLContext alloc] initWithName:@"JotViewMainThreadContext" andAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:mainThreadContext.sharegroup andValidateThreadWith:^BOOL{
            return [NSThread isMainThread];
        }];
    }
    
    if (!context) {
        return nil;
    }
    [context runBlock:^{
        // Set the view's scale factor
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
        
        // Setup OpenGL states
        glMatrixMode(GL_PROJECTION);
        
        // Setup the view port in Pixels
        glMatrixMode(GL_MODELVIEW);
        
        [context glDisableDither];
        [context glEnableTextures];
        [context glEnableBlend];
        [context glEnablePointSprites];
        // Set a blending function appropriate for premultiplied alpha pixel data
        [context glBlendFunc:GL_ONE and:GL_ONE_MINUS_SRC_ALPHA];
        
        [self destroyFramebuffer];
        [self createFramebuffer];
    }];

    [JotGLContext validateEmptyContextStack];
    
    
    
    return self;
}

#pragma mark - Dispatch Queues

static const void *const kImportExportImageQueueIdentifier = &kImportExportImageQueueIdentifier;

static const void *const kImportExportStateQueueIdentifier = &kImportExportStateQueueIdentifier;

+(dispatch_queue_t) importExportImageQueue{
    if(!importExportImageQueue){
        importExportImageQueue = dispatch_queue_create("com.milestonemade.looseleaf.importExportImageQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(importExportImageQueue, kImportExportImageQueueIdentifier, (void *)kImportExportImageQueueIdentifier, NULL);
    }
    return importExportImageQueue;
}

+(BOOL) isImportExportImageQueue{
    return dispatch_get_specific(kImportExportImageQueueIdentifier) != NULL;
}


+(dispatch_queue_t) importExportStateQueue{
    if(!importExportStateQueue){
        importExportStateQueue = dispatch_queue_create("com.milestonemade.looseleaf.importExportStateQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(importExportStateQueue, kImportExportStateQueueIdentifier, (void *)kImportExportStateQueueIdentifier, NULL);
    }
    return importExportStateQueue;
}

+(BOOL) isImportExportStateQueue{
    return dispatch_get_specific(kImportExportStateQueueIdentifier) != NULL;
}



#pragma mark - OpenGL Init



/**
 * this will create the framebuffer and related
 * render and depth buffers that we'll use for
 * drawing
 */
- (BOOL)createFramebuffer{
    CheckMainThread;
    
    
    viewFramebuffer = [[JotGLLayerBackedFrameBuffer alloc] initForLayer:(CALayer<EAGLDrawable>*)self.layer];

    [self clear:NO];
	
	return YES;
}

/**
 * Clean up any buffers we have allocated.
 */
- (void)destroyFramebuffer{
    
    JotGLContext* destroyContext = context;
    if(!destroyContext){
        // crash log from: https://crashlytics.com/milestonemade/ios/apps/com.milestonemade.looseleaf/issues/545172eae3de5099ba29598d/sessions/545171c803d1000153d9653633633632
        // shows a nil context at this point.
        // this code will generate a new context
        // that can be used to clean up any
        // GL assets.
        destroyContext = [[JotGLContext alloc] initWithName:@"JotViewDestroyFBOContext" andAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:mainThreadContext.sharegroup andValidateThreadWith:^BOOL{
            return YES;
        }];
    }
    
    [destroyContext runBlock:^{
        viewFramebuffer = nil;
        glFlush();
    }];
}



#pragma mark - Import and Export

/**
 * This method will load the input image into the drawable view
 * and will stretch it as appropriate to fill the area. For best results,
 * use an image that is the same size as the view's frame.
 *
 * This method will also reset the undo state of the view.
 *
 * This method must be called at least one time after initialization
 */
-(void) loadState:(JotViewStateProxy*)newState{
    CheckMainThread;
    if(state != newState){
        state = newState;
        [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:CGRectZero];
        if([state hasEditsToSave]){
            // be explicit about not letting us change the state of
            // the drawable view if there are saves pending.
            @throw [NSException exceptionWithName:@"JotViewException" reason:@"Changing JotView state with saves pending" userInfo:nil];
        }
        // at this point, we know that we've saved 100% of our
        // state to disk, but for some reason still have saves
        // pending.
        //
        // empty out this array - otherwise we'll try to save our
        // new state during this old invocation.
        //
        // https://github.com/adamwulf/loose-leaf/issues/533
        [exportLaterInvocations removeAllObjects];
    }
}

-(void) exportImageTo:(NSString*)inkPath
       andThumbnailTo:(NSString*)thumbnailPath
           andStateTo:(NSString*)plistPath
   withThumbnailScale:(CGFloat)thumbScale
           onComplete:(void(^)(UIImage* ink, UIImage* thumb, JotViewImmutableState* state))exportFinishBlock{
    
    // ask to save, and send in our state object
    // incase we need to defer saving until later
    [self exportImageTo:inkPath andThumbnailTo:thumbnailPath andStateTo:plistPath andJotState:state withThumbnailScale:@(thumbScale) onComplete:exportFinishBlock];
}

/**
 * i need to send out nil for the ink and thumbnail
 * if i can determine that either/both do not have any
 * user drawn content on them
 *
 * https://github.com/adamwulf/loose-leaf/issues/226
 */
-(void) exportImageTo:(NSString*)inkPath
       andThumbnailTo:(NSString*)thumbnailPath
           andStateTo:(NSString*)plistPath
          andJotState:(JotViewStateProxy*)stateToBeSaved
   withThumbnailScale:(NSNumber*)thumbScale
           onComplete:(void(^)(UIImage* ink, UIImage* thumb, JotViewImmutableState* state))exportFinishBlock{

    CheckMainThread;
    
    if(stateToBeSaved != state){
        @throw [NSException exceptionWithName:@"InvalidJotViewStateDuringSaveException" reason:@"JotView is asked to save with the wrong state object" userInfo:nil];
    }
    if(!stateToBeSaved){
        @throw [NSException exceptionWithName:@"InvalidJotViewStateDuringSaveException" reason:@"JotView is asked to save without a state object" userInfo:nil];
    }
    
    if(!state){
        exportFinishBlock(nil, nil, nil);
        return;
    }
    
    if(state.isForgetful){
        DebugLog(@"forget: skipping export for forgetful jotview");
        exportFinishBlock(nil, nil, nil);
        return;
    }
    
    if((![state isReadyToExport] || isCurrentlyExporting)){
        if(isCurrentlyExporting == [state undoHash]){
            //
            // we're already currently saving this undo hash,
            // so we don't need to add another save to the
            // exportLaterInvocation list
            exportFinishBlock(nil, nil, nil);
        }else if(![exportLaterInvocations count]){
            //
            // the issue here is that we want to export the drawn image to a file, but we're
            // also in the middle of writing all the strokes to the backing texture.
            //
            // instead of try to be super smart, and export while we draw (yikes!), we're going to
            // wait for all of the strokes to be written to the texture that need to be.
            //
            // then, the [validateUndoState] will re-call this export method with the same parameters
            // when it's done, and we'll bypass this block and finish the export.
            //
            // copy block to heap
            void(^block)(UIImage* ink, UIImage* thumb, NSDictionary* state) = [exportFinishBlock copy];
            SEL exportMethodSelector = @selector(exportImageTo:andThumbnailTo:andStateTo:andJotState:withThumbnailScale:onComplete:);
            NSMethodSignature * mySignature = [JotView instanceMethodSignatureForSelector:exportMethodSelector];
            NSInvocation* saveInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
            [saveInvocation setTarget:self];
            [saveInvocation setSelector:exportMethodSelector];
            [saveInvocation setArgument:&inkPath atIndex:2];
            [saveInvocation setArgument:&thumbnailPath atIndex:3];
            [saveInvocation setArgument:&plistPath atIndex:4];
            [saveInvocation setArgument:&state atIndex:5];
            [saveInvocation setArgument:&thumbScale atIndex:6];
            [saveInvocation setArgument:&block atIndex:7];
            [saveInvocation retainArguments];
            [exportLaterInvocations addObject:saveInvocation];
        }else{
            // we have to call the export finish block, no matter what.
            // so call the block and send nil b/c we're not actually done
            // exporting.
            exportFinishBlock(nil, nil, nil);
        }
        return;
    }
    
    @synchronized(self){
        isCurrentlyExporting = [state undoHash];
//        DebugLog(@"export begins: %p hash:%d", self, (int) state.undoHash);
    }
    
    dispatch_semaphore_t sema1 = dispatch_semaphore_create(0);
    dispatch_semaphore_t sema2 = dispatch_semaphore_create(0);
    
    __block UIImage* thumb = nil;
    __block UIImage* ink = nil;
    
    //
    // we need to save a version of the state at this exact
    // moment. after this method ends the state and/or strokes
    // inside the state may change.
    //
    // this immutable state will ensure that we have a handle
    // to the exact strokes that are visible + not yet written
    // to the backing texture
    JotViewImmutableState* immutableState = [state immutableState];
    
    [self exportInkTextureOnComplete:^(UIImage* image){
        ink = image;
        dispatch_semaphore_signal(sema2);
    }];
    

    // now grab the bits of the rendered thumbnail
    // and backing texture
    [self exportToImageOnComplete:^(UIImage* image){
        thumb = image;
        dispatch_semaphore_signal(sema1);
    } withScale:[thumbScale floatValue]];
    
    /////////////////////////////////////////////////////
    /////////////////////////////////////////////////////
    //
    // ok, right here we're halfway done with the export.
    // we have all of the information we need in memory,
    // and our next step is to write it to disk.
    //
    // we'll do the disk writing on a background thread
    // below. this will take the rendered items and
    // generate PNGs, and it will take our state and
    // serialize it out as a plist.
    //
    
    //
    // ok, here i walk off of the main thread,
    // and my state arrays might get changed while
    // i wait (yikes!).
    //
    // i need an immutable state that i can hold onto
    // while i wait + write to disk in the background
    //
    
    dispatch_async([JotView importExportStateQueue], ^(void) {
        @autoreleasepool {
            dispatch_semaphore_wait(sema1, DISPATCH_TIME_FOREVER);
            // i could notify about the thumbnail here
            // which would let the UI swap to the cached thumbnail
            // from the full JotUI if needed... (?)
            // probably an over optimization at this point,
            // but may be useful once multiple JotViews are
            // on screen at a time + being exported simultaneously
            
            dispatch_semaphore_wait(sema2, DISPATCH_TIME_FOREVER);
            
            dispatch_release(sema1);
            dispatch_release(sema2);
            
            exportFinishBlock(ink, thumb, immutableState);
            
            if(state.isForgetful){
                @synchronized(self){
                    isCurrentlyExporting = 0;
                }
                DebugLog(@"forget: skipping export write to disk for forgetful jotview");
                return;
            }
            
            if(ink){
                // we have the backing ink texture to save
                // so write it to disk
                [[JotDiskAssetManager sharedManager] writeImage:ink toPath:inkPath];
                //            DebugLog(@"writing ink to disk");
            }else{
                // the backing texture either hasn't changed, or
                // doesn't have anything written to it at all
                // so skip writing a blank PNG to disk
                //            DebugLog(@"skipping writing ink, nothing changed");
            }
            
            [[JotDiskAssetManager sharedManager] writeImage:thumb toPath:thumbnailPath];
            
            // this call will both serialize the state
            // and write it to disk
            [immutableState writeToDisk:plistPath];
            
            //        DebugLog(@"export complete");
            @synchronized(self){
                // we only ever want to export one at a time.
                // if anything has changed while we've been exporting
                // then that'll be held in the exportLaterInvocations
                // and will fire after we're done. (from validateUndoState).
                isCurrentlyExporting = 0;
            }
//            DebugLog(@"export ends: %p", self);
        }
    });
}


#pragma mark Export Helpers

/**
 * export an image from the openGL render buffer to a UIImage
 * @param backgroundColor an optional background color for the image. pass nil for a transparent background.
 * @param backgroundImage an optional image to use as the background behind this view's content
 *
 * code modified from http://developer.apple.com/library/ios/#qa/qa1704/_index.html
 *
 * If you plan to save the returned image to the photo library,
 * then you can maintain transparency by reformatting as a PNG:
 * [UIImage imageWithData:UIImagePNGRepresentation(imageReturnedByThisMethod)];
 *
 * If you don't reformat as a PNG, then you may lose transparency
 * when saving/loading from the Photo Library, as described here:
 * http://stackoverflow.com/questions/1489250/uiimagewritetosavedphotosalbum-save-as-png-with-transparency
 * and
 * http://stackoverflow.com/questions/1379274/uiimagewritetosavedphotosalbum-saves-to-wrong-size-and-quality
 */
-(void) exportToImageOnComplete:(void(^)(UIImage*) )exportFinishBlock withScale:(CGFloat)outputScale{
    
    CheckMainThread;
    
    if(!exportFinishBlock) return;
    
    if(![imageTextureLock tryLock]){
        DebugLog(@"gotcha");
        // save failed, just exit and our
        // caller can retry later
        exportFinishBlock(nil);
        return;
    }

//    [JotGLContext pushCurrentContext:context];
//    
//    JotGLTexture* fullTexture = [self generateTexture];
//    [fullTexture bind];
//    CGSize usefulTextureSize = CGSizeMake(ceilf(initialViewport.width), ceilf(initialViewport.height));
//    CGSize exportSize = CGSizeMake(ceilf(initialViewport.width / 2), ceilf(initialViewport.height / 2));
//    [context flush];
//    [fullTexture unbind];
//    [JotGLContext popCurrentContext];

    NSArray* strokesAtTimeOfExport = [state everyVisibleStroke];
    
    //
    // the rest can be done in Core Graphics in a background thread
    dispatch_async([JotView importExportImageQueue], ^{
        @autoreleasepool {
            if(state.isForgetful){
                DebugLog(@"forget: skipping export for forgetful jotview");
                exportFinishBlock(nil);
                [imageTextureLock unlock];
                return;
            }

            JotGLContext* secondSubContext = [[JotGLContext alloc] initWithName:@"JotViewExportToImageContext" andAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:mainThreadContext.sharegroup andValidateThreadWith:^BOOL{
                return [JotView isImportExportImageQueue];
            }];
            [secondSubContext runBlock:^{
                //            // finish current gl calls
                //            glFinish();
                
                // Setup OpenGL states
                glMatrixMode(GL_PROJECTION);
                
                // Setup the view port in Pixels
                glMatrixMode(GL_MODELVIEW);
                
                [secondSubContext glDisableDither];
                [secondSubContext glEnableTextures];
                [secondSubContext glEnableBlend];
                
                // Set a blending function appropriate for premultiplied alpha pixel data
                [secondSubContext glBlendFunc:GL_ONE and:GL_ONE_MINUS_SRC_ALPHA];
                
                [context glEnablePointSprites];
                
                CGSize fullSize = viewFramebuffer.initialViewport;
                CGSize exportSize = CGSizeMake(ceilf(fullSize.width * outputScale), ceilf(fullSize.height * outputScale));;
                
                glOrthof(0, (GLsizei) fullSize.width, 0, (GLsizei) fullSize.height, -1, 1);
                glViewport(0, 0, (GLsizei) fullSize.width, (GLsizei) fullSize.height);
                
                // create the texture
                // maxTextureSize
                CGSize maxTextureSize = [UIScreen mainScreen].portraitBounds.size;
                maxTextureSize.width *= [UIScreen mainScreen].scale;
                maxTextureSize.height *= [UIScreen mainScreen].scale;
                JotGLTexture* canvasTexture = [[JotTextureCache sharedManager] generateTextureForContext:secondSubContext ofSize:maxTextureSize];
                [canvasTexture bind];
                
                GLuint exportFramebuffer;
                
                glGenFramebuffersOES(1, &exportFramebuffer);
                glBindFramebufferOES(GL_FRAMEBUFFER_OES, exportFramebuffer);
                
                glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, canvasTexture.textureID, 0);
                [canvasTexture unbind];
                
                GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
                if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
                    NSString* str = [NSString stringWithFormat:@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)];
                    DebugLog(@"%@", str);
                    @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:str userInfo:nil];
                }
                
                glViewport(0, 0, fullSize.width, fullSize.height);
                
                // step 1:
                // Clear the buffer
                glClearColor(0.0, 0.0, 0.0, 0.0);
                glClear(GL_COLOR_BUFFER_BIT);
                
                // step 2:
                // load a texture and draw it into a quad
                // that fills the screen
                [state.backgroundTexture drawInContext:secondSubContext];
                
                // reset our viewport
                glViewport(0, 0, viewFramebuffer.initialViewport.width, viewFramebuffer.initialViewport.height);
                
                // we have to flush here to push all
                // the pixels to the texture so they're
                // available in the background thread's
                // context
                [secondSubContext flush];
                
                
                
                
                
                // now render strokes
                
                glBindFramebufferOES(GL_FRAMEBUFFER_OES, exportFramebuffer);
                
                [secondSubContext glEnableClientState:GL_VERTEX_ARRAY];
                [secondSubContext glEnableClientState:GL_COLOR_ARRAY];
                [secondSubContext glEnableClientState:GL_POINT_SIZE_ARRAY_OES];
                [secondSubContext disableTextureCoordArray];
                
                for(JotStroke* stroke in strokesAtTimeOfExport){
                    [stroke lock];
                    // make sure our texture is the correct one for this stroke
                    [stroke.texture bind];
                    
                    // draw each stroke element
                    AbstractBezierPathElement* prevElement = nil;
                    for(AbstractBezierPathElement* element in stroke.segments){
                        [self renderElement:element fromPreviousElement:prevElement includeOpenGLPrepForFBO:nil toContext:secondSubContext];
                        prevElement = element;
                    }
                    [stroke.texture unbind];
                    [stroke unlock];
                }
                
                
                
                
                ////////////////////////////////
                // render to texture is done,
                // now read its contents
                //
                
                // now read its contents
                
                [secondSubContext flush];
                [canvasTexture bind];
                glViewport(0, 0, fullSize.width, fullSize.height);
                glFlush();
                
                status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
                if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
                    NSString* str = [NSString stringWithFormat:@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)];
                    DebugLog(@"%@", str);
                    @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:str userInfo:nil];
                }
                // step 3:
                // read the image from OpenGL and push it into a data buffer
                GLint x = 0, y = 0; //, width = backingWidthForRenderBuffer, height = backingHeightForRenderBuffer;
                NSInteger dataLength = fullSize.width * fullSize.height * 4;
                GLubyte *data = calloc(fullSize.height * fullSize.width, 4);
                if(!data){
                    @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't malloc" userInfo:nil];
                }
                // Read pixel data from the framebuffer
                glPixelStorei(GL_PACK_ALIGNMENT, 4);
                glReadPixels(x, y, fullSize.width, fullSize.height, GL_RGBA, GL_UNSIGNED_BYTE, data);
                
                // now we're done, delete our buffers
                glDeleteFramebuffersOES(1, &exportFramebuffer);
                [canvasTexture unbind];
                [[JotTextureCache sharedManager] returnTextureForReuse:canvasTexture];
                
                
                
                // Create a CGImage with the pixel data from OpenGL
                // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
                // otherwise, use kCGImageAlphaPremultipliedLast
                CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
                CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
                CGImageRef iref = CGImageCreate(fullSize.width, fullSize.height, 8, 32, fullSize.width * 4, colorspace, kCGBitmapByteOrderDefault |
                                                kCGImageAlphaPremultipliedLast,
                                                ref, NULL, true, kCGRenderingIntentDefault);
                
                // ok, now we have the pixel data from the OpenGL frame buffer.
                // next we need to setup the image context to composite the
                // background color, background image, and opengl image
                
                // OpenGL ES measures data in PIXELS
                // Create a graphics context with the target size measured in POINTS
                CGContextRef bitmapContext = CGBitmapContextCreate(NULL, exportSize.width, exportSize.height, 8, exportSize.width * 4, colorspace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
                if(!bitmapContext){
                    @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
                }
                
                // can I clear less stuff and still be ok?
                CGContextClearRect(bitmapContext, CGRectMake(0, 0, exportSize.width, exportSize.height));
                
                if(!bitmapContext){
                    DebugLog(@"oh no1");
                }
                
                // flip vertical for our drawn content, since OpenGL is opposite core graphics
                CGContextTranslateCTM(bitmapContext, 0, exportSize.height);
                CGContextScaleCTM(bitmapContext, 1.0, -1.0);
                
                //
                // ok, now render our actual content
                CGContextDrawImage(bitmapContext, CGRectMake(0.0, 0.0, exportSize.width, exportSize.height), iref);
                
                // Retrieve the UIImage from the current context
                CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
                if(!cgImage){
                    @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
                }
                
                UIImage* image = [UIImage imageWithCGImage:cgImage scale:self.contentScaleFactor orientation:UIImageOrientationUp];
                
                // Clean up
                free(data);
                CFRelease(ref);
                CFRelease(colorspace);
                CGImageRelease(iref);
                CGContextRelease(bitmapContext);
                
                // ok, we're done exporting and cleaning up
                // so pass the newly generated image to the completion block
                exportFinishBlock(image);
                CGImageRelease(cgImage);
            }];
            
            [JotGLContext validateEmptyContextStack];
            dispatch_async(dispatch_get_main_queue(), ^{
                // can't do this sync()
                // because the main thread + the importExportImageQueue
                // could deadlock
                [imageTextureLock unlock];
            });
        }
    });
}


/**
 * export an image from the openGL render buffer to a UIImage
 * @param backgroundColor an optional background color for the image. pass nil for a transparent background.
 * @param backgroundImage an optional image to use as the background behind this view's content
 *
 * code modified from http://developer.apple.com/library/ios/#qa/qa1704/_index.html
 *
 * If you plan to save the returned image to the photo library,
 * then you can maintain transparency by reformatting as a PNG:
 * [UIImage imageWithData:UIImagePNGRepresentation(imageReturnedByThisMethod)];
 *
 * If you don't reformat as a PNG, then you may lose transparency
 * when saving/loading from the Photo Library, as described here:
 * http://stackoverflow.com/questions/1489250/uiimagewritetosavedphotosalbum-save-as-png-with-transparency
 * and
 * http://stackoverflow.com/questions/1379274/uiimagewritetosavedphotosalbum-saves-to-wrong-size-and-quality
 */
-(void) exportInkTextureOnComplete:(void(^)(UIImage*) )exportFinishBlock{
    
    CheckMainThread;
    
    if(!state){
        if(exportFinishBlock) exportFinishBlock(nil);
        return;
    }
    
    if(!exportFinishBlock) return;

    if(![inkTextureLock tryLock]){
        DebugLog(@"gotcha");
        // save failed, just exit and our
        // caller can retry later
        exportFinishBlock(nil);
        return;
    }
    
    // the rest can be done in Core Graphics in a background thread
    dispatch_async([JotView importExportImageQueue], ^{
        @autoreleasepool {
            if(state.isForgetful){
                DebugLog(@"forget: skipping export for forgetful jotview");
                exportFinishBlock(nil);
                [inkTextureLock unlock];
                return;
            }

            JotGLContext* secondSubContext = [[JotGLContext alloc] initWithName:@"JotViewExportInkTextureContext" andAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:mainThreadContext.sharegroup andValidateThreadWith:^BOOL{
                return [JotView isImportExportImageQueue];
            }];
            [secondSubContext runBlock:^{
                // finish current gl calls
                //            glFinish();
                
                // Setup OpenGL states
                glMatrixMode(GL_PROJECTION);
                
                // Setup the view port in Pixels
                glMatrixMode(GL_MODELVIEW);
                
                [secondSubContext glDisableDither];
                [secondSubContext glEnableTextures];
                [secondSubContext glEnableBlend];

                // Set a blending function appropriate for premultiplied alpha pixel data
                [secondSubContext glBlendFunc:GL_ONE and:GL_ONE_MINUS_SRC_ALPHA];
                
                [context glEnablePointSprites];
                
                CGSize initialViewport = viewFramebuffer.initialViewport;
                
                glOrthof(0, (GLsizei) initialViewport.width, 0, (GLsizei) initialViewport.height, -1, 1);
                glViewport(0, 0, (GLsizei) initialViewport.width, (GLsizei) initialViewport.height);
                
                CGSize fullSize = CGSizeMake(ceilf(initialViewport.width), ceilf(initialViewport.height));
                CGSize exportSize = CGSizeMake(ceilf(initialViewport.width), ceilf(initialViewport.height));
                
                // create the texture
                // maxTextureSize
                CGSize maxTextureSize = [UIScreen mainScreen].portraitBounds.size;
                maxTextureSize.width *= [UIScreen mainScreen].scale;
                maxTextureSize.height *= [UIScreen mainScreen].scale;
                JotGLTexture* canvasTexture = [[JotTextureCache sharedManager] generateTextureForContext:secondSubContext ofSize:maxTextureSize];
                [canvasTexture bind];
                
                GLuint exportFramebuffer;
                
                glGenFramebuffersOES(1, &exportFramebuffer);
                glBindFramebufferOES(GL_FRAMEBUFFER_OES, exportFramebuffer);
                
                glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, canvasTexture.textureID, 0);
                [canvasTexture unbind];
                
                GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
                if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
                    NSString* str = [NSString stringWithFormat:@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)];
                    DebugLog(@"%@", str);
                    @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:str userInfo:nil];
                }
                
                glViewport(0, 0, fullSize.width, fullSize.height);
                
                // step 1:
                // Clear the buffer
                glClearColor(0.0, 0.0, 0.0, 0.0);
                glClear(GL_COLOR_BUFFER_BIT);
                
                // step 2:
                // load a texture and draw it into a quad
                // that fills the screen
                [state.backgroundTexture drawInContext:secondSubContext];
                
                // reset our viewport
                glViewport(0, 0, initialViewport.width, initialViewport.height);
                
                // we have to flush here to push all
                // the pixels to the texture so they're
                // available in the background thread's
                // context
                [secondSubContext flush];
                glFlush();
                
                
                
                
                
                
                
                // now read its contents
                
                [secondSubContext flush];
                [canvasTexture bind];
                glViewport(0, 0, fullSize.width, fullSize.height);
                glFlush();
                
                status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
                if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
                    NSString* str = [NSString stringWithFormat:@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)];
                    DebugLog(@"%@", str);
                    @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:str userInfo:nil];
                }
                // step 3:
                // read the image from OpenGL and push it into a data buffer
                GLint x = 0, y = 0; //, width = backingWidthForRenderBuffer, height = backingHeightForRenderBuffer;
                NSInteger dataLength = fullSize.width * fullSize.height * 4;
                GLubyte *data = calloc(fullSize.height * fullSize.width, 4);
                if(!data){
                    @throw [NSException exceptionWithName:@"Memory Exception" reason:@"can't malloc" userInfo:nil];
                }
                // Read pixel data from the framebuffer
                glPixelStorei(GL_PACK_ALIGNMENT, 4);
                glReadPixels(x, y, fullSize.width, fullSize.height, GL_RGBA, GL_UNSIGNED_BYTE, data);
                
                // now we're done, delete our buffers
                glDeleteFramebuffersOES(1, &exportFramebuffer);
                [canvasTexture unbind];
                [[JotTextureCache sharedManager] returnTextureForReuse:canvasTexture];
                
                
                
                // Create a CGImage with the pixel data from OpenGL
                // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
                // otherwise, use kCGImageAlphaPremultipliedLast
                CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
                CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
                CGImageRef iref = CGImageCreate(fullSize.width, fullSize.height, 8, 32, fullSize.width * 4, colorspace, kCGBitmapByteOrderDefault |
                                                kCGImageAlphaPremultipliedLast,
                                                ref, NULL, true, kCGRenderingIntentDefault);
                
                // ok, now we have the pixel data from the OpenGL frame buffer.
                // next we need to setup the image context to composite the
                // background color, background image, and opengl image
                
                // OpenGL ES measures data in PIXELS
                // Create a graphics context with the target size measured in POINTS
                CGContextRef bitmapContext = CGBitmapContextCreate(NULL, exportSize.width, exportSize.height, 8, exportSize.width * 4, colorspace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
                if(!bitmapContext){
                    @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
                }
                
                // can I clear less stuff and still be ok?
                CGContextClearRect(bitmapContext, CGRectMake(0, 0, exportSize.width, exportSize.height));
                
                if(!bitmapContext){
                    DebugLog(@"oh no1");
                }
                
                // flip vertical for our drawn content, since OpenGL is opposite core graphics
                CGContextTranslateCTM(bitmapContext, 0, exportSize.height);
                CGContextScaleCTM(bitmapContext, 1.0, -1.0);
                
                //
                // ok, now render our actual content
                CGContextDrawImage(bitmapContext, CGRectMake(0.0, 0.0, exportSize.width, exportSize.height), iref);
                
                // Retrieve the UIImage from the current context
                CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
                if(!cgImage){
                    @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
                }
                
                UIImage* image = [UIImage imageWithCGImage:cgImage scale:self.contentScaleFactor orientation:UIImageOrientationUp];
                
                // Clean up
                free(data);
                CFRelease(ref);
                CFRelease(colorspace);
                CGImageRelease(iref);
                CGContextRelease(bitmapContext);
                
                // ok, we're done exporting and cleaning up
                // so pass the newly generated image to the completion block
                exportFinishBlock(image);
                CGImageRelease(cgImage);
            }];
            [JotGLContext validateEmptyContextStack];
            dispatch_async(dispatch_get_main_queue(), ^{
                // can't do this sync()
                // because the main thread + the importExportImageQueue
                // could deadlock
                [inkTextureLock unlock];
            });
        }
    });
}



#pragma mark - Rendering

/**
 * this method will re-render all of the strokes that
 * we have in our undo-able buffer.
 *
 * this can be used if a user cancells a stroke or undos
 * a stroke. it will clear the screen and re-draw all
 * strokes except for that undone/cancelled stroke
 */
-(void) renderAllStrokesToContext:(JotGLContext*)renderContext inFramebuffer:(AbstractJotGLFrameBuffer*)theFramebuffer andPresentBuffer:(BOOL)shouldPresent inRect:(CGRect)scissorRect{
    @autoreleasepool {
        
        CheckMainThread;
        
        if(!state) return;
        
        // set our current OpenGL context
        [renderContext runBlock:^{
            if(!CGRectEqualToRect(scissorRect, CGRectZero)){
                glEnable(GL_SCISSOR_TEST);
                glScissor(scissorRect.origin.x, scissorRect.origin.y, scissorRect.size.width, scissorRect.size.height);
            }else{
                // noop for scissors
            }
            
            [theFramebuffer bind];
            
            //
            // step 1:
            // Clear the buffer
            glClearColor(0.0, 0.0, 0.0, 0.0);
            glClear(GL_COLOR_BUFFER_BIT);
            
            //
            // step 2:
            // load a texture and draw it into a quad
            // that fills the screen
            [state.backgroundTexture drawInContext:renderContext];
            
            if(!state.backgroundTexture){
                DebugLog(@"what5");
            }
            
            //
            // ok, we're done rendering the background texture to the quad
            //
            
            //
            // step 3:
            // draw all the strokes that we have in our undo-able stack
            [self prepOpenGLStateForFBO:theFramebuffer toContext:renderContext];
            // reset the texture so that we load the brush texture next
            // now draw the strokes
            
            for(JotStroke* stroke in [state everyVisibleStroke]){
                [stroke lock];
                // make sure our texture is the correct one for this stroke
                [stroke.texture bind];
                
                // draw each stroke element
                AbstractBezierPathElement* prevElement = nil;
                for(AbstractBezierPathElement* element in stroke.segments){
                    [self renderElement:element fromPreviousElement:prevElement includeOpenGLPrepForFBO:nil toContext:renderContext];
                    prevElement = element;
                }
                [stroke.texture unbind];
                [stroke unlock];
            }
            [self unprepOpenGLState];

            //    DebugLog(@"done render all: %d", c);
            
            if(shouldPresent){
                // step 4:
                // ok, show it!
                [self setNeedsPresentRenderBuffer];
            }
            
            [theFramebuffer unbind];
            if(!CGRectEqualToRect(scissorRect, CGRectZero)){
                glDisable(GL_SCISSOR_TEST);
            }
        }];
    }
}


/**
 * cut our framerate by half
 */
-(void) slowDownFPS{
    viewFramebuffer.shouldslow = YES;
}
/**
 * call this to unlimit our FPS back to
 * the full hardware limit
 */
-(void) speedUpFPS{
    viewFramebuffer.shouldslow = NO;
}

CGFloat JotBNRTimeBlock (void (^block)(void)) {
    mach_timebase_info_data_t info;
    if (mach_timebase_info(&info) != KERN_SUCCESS) return -1.0;
    
    uint64_t start = mach_absolute_time ();
    block ();
    uint64_t end = mach_absolute_time ();
    uint64_t elapsed = end - start;
    
    uint64_t nanos = elapsed * info.numer / info.denom;
    return (CGFloat)nanos / NSEC_PER_SEC;
    
} // BNRTimeBlock

-(void) displayLinkPresentRenderBuffer:(CADisplayLink*)link{
    [self presentRenderBuffer];
}

/**
 * this is a simple method to display our renderbuffer
 */
-(void) presentRenderBuffer{
    CheckMainThread;
    
    if(!state) return;

    [viewFramebuffer presentRenderBufferInContext:self.context];
}

-(void) setNeedsPresentRenderBuffer{
    [viewFramebuffer setNeedsPresentRenderBuffer];
}


/**
 * Drawings a line onscreen based on where the user touches
 *
 * this will add the end point to the current stroke, and will
 * then render that new stroke segment to the gl context
 *
 * it will smooth a rounded line from the previous segment, and will
 * also smooth the width and color transition
 */
- (BOOL) addLineToAndRenderStroke:(JotStroke*)currentStroke toPoint:(CGPoint)end toWidth:(CGFloat)width toColor:(UIColor*)color andSmoothness:(CGFloat)smoothFactor{
    CheckMainThread;
    [currentStroke lock];
    // now we render to ourselves
    

    // fetch the current and previous elements
    // of the stroke. these will help us
    // step over their length for drawing
    AbstractBezierPathElement* previousElement = [currentStroke.segments lastObject];
    
    // Convert touch point from UIView referential to OpenGL one (upside-down flip)
    end.y = self.bounds.size.height - end.y;
    

    // add the segment to the stroke if we can
    AbstractBezierPathElement* addedElement = [currentStroke.segmentSmoother addPoint:end andSmoothness:smoothFactor];
    // a new element wasn't possible, so just bail here.
    if(!addedElement){
        [currentStroke unlock];
        return NO;
    }
    [context runBlock:^{
        // ok, we have the new element, set its color/width/rotation
        addedElement.color = color;
        addedElement.width = width;
        // now tell the stroke that it's added
        
        // let our delegate have an opportunity to modify the element array
        NSArray* elements = [self.delegate willAddElementsToStroke:[NSArray arrayWithObject:addedElement] fromPreviousElement:previousElement];
        
        // prepend the previous element, so that each of our new elements has a previous element to
        // render with
        elements = [[NSArray arrayWithObject:(previousElement ? previousElement : [NSNull null])] arrayByAddingObjectsFromArray:elements];
        [currentStroke.texture bind];
        for(int i=1;i<[elements count];i++){
            [currentStroke addElement:[elements objectAtIndex:i]];
            // ok, now we have the current + previous stroke segment
            // so let's set to drawing it!
            [self renderElement:[elements objectAtIndex:i] fromPreviousElement:[elements objectAtIndex:i-1] includeOpenGLPrepForFBO:viewFramebuffer toContext:context];
        }
        [currentStroke.texture unbind];
        
        // Display the buffer
        [self setNeedsPresentRenderBuffer];
    }];

    [currentStroke unlock];
    return YES;
}


/**
 * this renders a single stroke segment to the glcontext.
 *
 * this assumes that this has been called:
 * [JotGLContext pushCurrentContext:];
 * glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
 *
 * and also assumes that this will be called after
 * all rendering is done:
 * glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
 * [context presentRenderbuffer:GL_RENDERBUFFER_OES];
 *
 * @param includeOpenGLPrepForFBO this signals whether we need to setup and
 * teardown our openGL context/blending/etc. send in the framebuffer id to
 * setup the openGL state, or send in nil or 0 to bypass setup
 */
-(void) renderElement:(AbstractBezierPathElement*)element fromPreviousElement:(AbstractBezierPathElement*)previousElement includeOpenGLPrepForFBO:(AbstractJotGLFrameBuffer*)frameBuffer toContext:(JotGLContext*)renderContext{
    
    if(!state) return;
    
    [JotGLContext validateContextMatches:renderContext];
    
    if(frameBuffer){
        // draw the stroke element
        [frameBuffer bind];
        [self prepOpenGLStateForFBO:frameBuffer toContext:renderContext];
    }
    // always prep the blend mode, the context
    // will cache the result so it won't over set
    // the gl state
    [renderContext prepOpenGLBlendModeForColor:element.color];
    
    if([[NSNull null] isEqual:previousElement]){
        previousElement = nil;
    }
    
    // find our screen scale so that we can convert from
    // points to pixels
    CGFloat scale = self.contentScaleFactor;
        
    // fetch the vertex data from the element
    [element generatedVertexArrayWithPreviousElement:previousElement forScale:scale];
    
    // now bind and draw the element
    [element drawGivenPreviousElement:previousElement];
    
    if(frameBuffer){
        [self unprepOpenGLState];
        [frameBuffer unbind];
    }
}

/**
 * this will prepare the OpenGL state to draw
 * a Vertex array for all of the points along
 * the line. each of our vertices contains the
 * point location, color info, and the size
 */
-(void) prepOpenGLStateForFBO:(AbstractJotGLFrameBuffer*)frameBuffer toContext:(JotGLContext*)renderContext{
    CheckMainThread;
    
    [renderContext glEnableClientState:GL_VERTEX_ARRAY];
    [renderContext glEnableClientState:GL_COLOR_ARRAY];
    [renderContext glEnableClientState:GL_POINT_SIZE_ARRAY_OES];
    [renderContext disableTextureCoordArray];
}

/**
 * after drawing, calling this function will
 * restore the OpenGL state so that it doesn't
 * linger if we want to draw a different way
 * later
 */
-(void) unprepOpenGLState{
    // Restore state
    // I used to disable all the client states that I had enabled
    // before, but now that I handle this in the JotGLContext,
    // I get better performance, and only adjust state
    // immediately before a draw call, and only
    // if the state actually needs changing
}




static int undoCounter;

/**
 * This method will make sure we only keep undoLimit
 * number of strokes. All others should be written to
 * our backing texture
 */
-(void) validateUndoState:(NSTimer *)timer{
    CheckMainThread;
    if([inkTextureLock tryLock]){
        if([imageTextureLock tryLock]){
            // only write to the bg texture if we can
            // lock on both ink + image
            [JotGLContext validateEmptyContextStack];
            
            CheckMainThread;
            
            // ticking the state will make sure that the state is valid,
            // containing only the correct number of undoable items in its
            // arrays, and putting all excess strokes into strokesBeingWrittenToBackingTexture
            [state tick];
            
            if([state.strokesBeingWrittenToBackingTexture count]){
                [context runBlock:^{
                    
                    undoCounter++;
                    if(undoCounter % 3 == 0){
                        //            DebugLog(@"strokes waiting to write: %lu", (unsigned long)[state.strokesBeingWrittenToBackingTexture count]);
                        undoCounter = 0;
                    }
                    // get the stroke that we need to make permanent
                    JotStroke* strokeToWriteToTexture = [state.strokesBeingWrittenToBackingTexture objectAtIndex:0];
                    [strokeToWriteToTexture lock];
                    // render it to the backing texture
                    [state.backgroundFramebuffer bind];
                    [self prepOpenGLStateForFBO:state.backgroundFramebuffer toContext:context];
                    
                    [strokeToWriteToTexture.texture bind];
                    // draw each stroke element. for performance reasons, we'll only
                    // draw ~ 300 pixels of segments at a time.
                    NSInteger distance = 0;
                    while([strokeToWriteToTexture.segments count] && distance < 300){
                        AbstractBezierPathElement* element = [strokeToWriteToTexture.segments objectAtIndex:0];
                        [strokeToWriteToTexture removeElementAtIndex:0];
                        [self renderElement:element fromPreviousElement:prevElementForTextureWriting includeOpenGLPrepForFBO:nil toContext:context];
                        prevElementForTextureWriting = element;
                        distance += [element lengthOfElement];
                        // this should dealloc the element immediately,
                        // and the VBO its using internally will be recycled
                        // in to the JotBufferManager
                    }
                    [strokeToWriteToTexture.texture unbind];
                    // now that we're done with the stroke,
                    // let's throw it in the trash
                    [strokeToWriteToTexture unlock];
                    if([strokeToWriteToTexture.segments count] == 0){
                        [state.strokesBeingWrittenToBackingTexture removeSingleObject:strokeToWriteToTexture];
                        [[JotTrashManager sharedInstance] addObjectToDealloc:strokeToWriteToTexture];
                        prevElementForTextureWriting = nil;
                    }
                    [self unprepOpenGLState];
                    [state.backgroundFramebuffer unbind];
                    
                    //
                    // we just drew to the backing texture, so be sure
                    // to flush all openGL commands, so that when we rebind
                    // it'll use the updated texture and won't have any
                    // issues of unsynchronized textures.
                    // popping will flush the context
                }];
                [imageTextureLock unlock];
                [inkTextureLock unlock];
            }else if([state isReadyToExport]){
                [imageTextureLock unlock];
                [inkTextureLock unlock];
                // only export if the trash manager is empty
                // that way we're exporting w/ low memory instead
                // of unknown memory
                if(![[JotTrashManager sharedInstance] tick]){
                    // ok, the trash is empty, so now see if we need to export
                    if([exportLaterInvocations count]){
                        NSInvocation* invokation = [exportLaterInvocations objectAtIndex:0];
                        [exportLaterInvocations removeSingleObject:invokation];
                        [invokation invoke];
                    }
                }
            }else{
                [imageTextureLock unlock];
                [inkTextureLock unlock];
            }
            [JotGLContext validateEmptyContextStack];
        }else{
//            DebugLog(@"skipping writing to ink texture during export2");
            [inkTextureLock unlock];
        }
    }else{
//        DebugLog(@"skipping writing to ink texture during export");
    }
}


#pragma mark - JotStrokeDelegate

-(void) jotStrokeWasCancelled:(JotStroke*)stroke{

    CheckMainThread;
    
    JotStroke* aStroke = state.currentStroke;
    if(aStroke == stroke){
        [self.delegate willCancelStroke:aStroke withTouch:nil];
        state.currentStroke = nil;
        if([aStroke.segments count] > 1 || ![[aStroke.segments firstObject] isKindOfClass:[MoveToPathElement class]]){
            CGFloat scale = [[UIScreen mainScreen] scale];
            CGRect bounds = [stroke bounds];
            bounds = CGRectApplyAffineTransform(bounds, CGAffineTransformMakeScale(scale, scale));
            [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:bounds];
        }
        [self.delegate didCancelStroke:aStroke withTouch:nil];
        return;
    }
}

#pragma mark - JotPalmRejectionDelegate

-(void) drawLongLine{
    if(!state) return;
    JotStroke* newStroke = [[JotStroke alloc] initWithTexture:[JotDefaultBrushTexture sharedInstance] andBufferManager:state.bufferManager];
    [newStroke lock];
    newStroke.delegate = self;
    [self addLineToAndRenderStroke:newStroke
                           toPoint:CGPointMake(100, 100)
                           toWidth:6
                           toColor:[UIColor redColor]
                     andSmoothness:0.7];
    [self addLineToAndRenderStroke:newStroke
                           toPoint:CGPointMake(100, 100)
                           toWidth:6
                           toColor:[UIColor redColor]
                     andSmoothness:0.7];
    
    [self addLineToAndRenderStroke:newStroke
                           toPoint:CGPointMake(700, 700)
                           toWidth:6
                           toColor:[UIColor redColor]
                     andSmoothness:0.7];
    [self addLineToAndRenderStroke:newStroke
                           toPoint:CGPointMake(700, 700)
                           toWidth:30
                           toColor:[UIColor blueColor]
                     andSmoothness:0.7];
    
    [state forceAddStroke:newStroke];
    
    [self.delegate didEndStrokeWithTouch:nil];
    [newStroke unlock];
}

/**
 * Handles the start of a touch
 */
-(void)jotStylusTouchBegan:(NSSet *) touches{
    
    CheckMainThread;
    
    if(!state) return;
    
    for(JotTouch* jotTouch in touches){
        if([self.delegate willBeginStrokeWithTouch:jotTouch]){
            JotStroke* newStroke = [[JotStrokeManager sharedInstance] makeStrokeForTouchHash:jotTouch.touch andTexture:[JotDefaultBrushTexture sharedInstance] andBufferManager:state.bufferManager];
            newStroke.delegate = self;
            if(state.currentStroke){
                @throw [NSException exceptionWithName:@"MultipleStrokeException" reason:@"Only 1 stroke is allowed at a time" userInfo:nil];
            }
            state.currentStroke = newStroke;
            // find the stroke that we're modifying, and then add an element and render it
            [self addLineToAndRenderStroke:newStroke
                                   toPoint:[jotTouch locationInView:self]
                                   toWidth:[self.delegate widthForTouch:jotTouch]
                                   toColor:[self.delegate colorForTouch:jotTouch]
                             andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
        }
    }
    [JotGLContext validateEmptyContextStack];
}

/**
 * Handles the continuation of a touch.
 */
-(void)jotStylusTouchMoved:(NSSet *) touches{
    
    CheckMainThread;
    
    if(!state) return;

    for(JotTouch* jotTouch in touches){
        [self.delegate willMoveStrokeWithTouch:jotTouch];
        JotStroke* currentStroke = [[JotStrokeManager sharedInstance] getStrokeForTouchHash:jotTouch.touch];
        if(currentStroke){
            // find the stroke that we're modifying, and then add an element and render it
            [self addLineToAndRenderStroke:currentStroke
                                   toPoint:[jotTouch locationInView:self]
                                   toWidth:[self.delegate widthForTouch:jotTouch]
                                   toColor:[self.delegate colorForTouch:jotTouch]
                             andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
        }
    }
    [JotGLContext validateEmptyContextStack];
}

/**
 * Handles the end of a touch event when the touch is a tap.
 */
-(void)jotStylusTouchEnded:(NSSet *) touches{
    
    CheckMainThread;
    
    if(!state) return;

    for(JotTouch* jotTouch in touches){
        [self.delegate willEndStrokeWithTouch:jotTouch];
        JotStroke* currentStroke = [[JotStrokeManager sharedInstance] getStrokeForTouchHash:jotTouch.touch];
        [currentStroke lock];
        if(currentStroke){
            // move to this endpoint
            [self jotStylusTouchMoved:touches];
            // now line to the end of the stroke
            [self addLineToAndRenderStroke:currentStroke
                                   toPoint:[jotTouch locationInView:self]
                                   toWidth:[self.delegate widthForTouch:jotTouch]
                                   toColor:[self.delegate colorForTouch:jotTouch]
                             andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
            
            // this stroke is now finished, so add it to our completed strokes stack
            // and remove it from the current strokes, and reset our undo state if any
            if([currentStroke.segments count] == 1 && [[currentStroke.segments firstObject] isKindOfClass:[MoveToPathElement class]]){
                DebugLog(@"only a move to, ignore");
                // this happen if the entire stroke lands inside of scraps, and nothing makes it to the bottom page
                [currentStroke empty];
            }
            [state finishCurrentStroke];

            [[JotStrokeManager sharedInstance] removeStrokeForTouch:jotTouch.touch];
            
            [self.delegate didEndStrokeWithTouch:jotTouch];
        }
        [currentStroke unlock];
    }
    [JotGLContext validateEmptyContextStack];
}

/**
 * Handles the end of a touch event.
 */
-(void)jotStylusTouchCancelled:(NSSet *) touches{
    
    CheckMainThread;
    
    if(!state) return;

    for(JotTouch* jotTouch in touches){
        // If appropriate, add code necessary to save the state of the application.
        // This application is not saving state.
        if([[JotStrokeManager sharedInstance] cancelStrokeForTouch:jotTouch.touch]){
            state.currentStroke = nil;
        }
    }
    // we need to erase the current stroke from the screen, so
    // clear the canvas and rerender all valid strokes
    [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:CGRectZero];
    [JotGLContext validateEmptyContextStack];
}


-(void)jotSuggestsToDisableGestures{
    
    CheckMainThread;
    
    if([self.delegate respondsToSelector:@selector(jotSuggestsToDisableGestures)]){
        [self.delegate jotSuggestsToDisableGestures];
    }
    
}
-(void)jotSuggestsToEnableGestures{
    
    CheckMainThread;
    
    if([self.delegate respondsToSelector:@selector(jotSuggestsToEnableGestures)]){
        [self.delegate jotSuggestsToEnableGestures];
    }
}



#pragma mark - UITouch Events

/**
 * If the Jot SDK is enabled, then all Jot stylus
 * events will be sent to the jotStylus: delegate methods.
 * All touches, regardless of if they map to a Jot stylus
 * event, will always be sent to the iOS touch methods.
 *
 * The iOS touch methods can be used to draw
 * for other brands of stylus
 *
 * for this example app, we'll simply draw every touch only if
 * the jot sdk is not enabled.
 */
-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    if(!state) return;

    if(![JotStylusManager sharedInstance].isStylusConnected){
        for (UITouch *touch in touches) {
            @autoreleasepool {
                JotTouch* jotTouch = [JotTouch jotTouchFor:touch];
                if([self.delegate willBeginStrokeWithTouch:jotTouch]){
                    JotStroke* newStroke = [[JotStrokeManager sharedInstance] makeStrokeForTouchHash:jotTouch.touch andTexture:[JotDefaultBrushTexture sharedInstance] andBufferManager:state.bufferManager];
                    newStroke.delegate = self;
                    state.currentStroke = newStroke;
                    // find the stroke that we're modifying, and then add an element and render it
                    [self addLineToAndRenderStroke:newStroke
                                           toPoint:[touch locationInView:self]
                                           toWidth:[self.delegate widthForTouch:jotTouch]
                                           toColor:[self.delegate colorForTouch:jotTouch]
                                     andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
                }
            }
        }
    }
    [JotGLContext validateEmptyContextStack];
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{

    if(!state) return;

    if(![JotStylusManager sharedInstance].isStylusConnected){
        for (UITouch *touch in touches) {
            @autoreleasepool {
                // check for other brands of stylus,
                // or process non-Jot touches
                //
                // for this example, we'll simply draw every touch if
                // the jot sdk is not enabled
                JotTouch* jotTouch = [JotTouch jotTouchFor:touch];
                [self.delegate willMoveStrokeWithTouch:jotTouch];
                JotStroke* currentStroke = [[JotStrokeManager sharedInstance] getStrokeForTouchHash:jotTouch.touch];
                if(currentStroke){
                    // find the stroke that we're modifying, and then add an element and render it
                    [self addLineToAndRenderStroke:currentStroke
                                           toPoint:[touch locationInView:self]
                                           toWidth:[self.delegate widthForTouch:jotTouch]
                                           toColor:[self.delegate colorForTouch:jotTouch]
                                     andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
                }
            }
        }
    }
    [JotGLContext validateEmptyContextStack];
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{

    if(!state) return;

    if(![JotStylusManager sharedInstance].isStylusConnected){
        for(UITouch* touch in touches){
            @autoreleasepool {
                // now line to the end of the stroke
                JotTouch* jotTouch = [JotTouch jotTouchFor:touch];
                [self.delegate willEndStrokeWithTouch:jotTouch];
                JotStroke* currentStroke = [[JotStrokeManager sharedInstance] getStrokeForTouchHash:jotTouch.touch];
                [currentStroke lock];
                if(currentStroke){
                    // move to this endpoint
                    [self touchesMoved:[NSSet setWithObject:touch] withEvent:event];
                    // now line to the end of the stroke
                    
                    [self addLineToAndRenderStroke:currentStroke
                                           toPoint:[touch locationInView:self]
                                           toWidth:[self.delegate widthForTouch:jotTouch]
                                           toColor:[self.delegate colorForTouch:jotTouch]
                                     andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
                    
                    // this stroke is now finished, so add it to our completed strokes stack
                    // and remove it from the current strokes, and reset our undo state if any
                    if([currentStroke.segments count] == 1 && [[currentStroke.segments firstObject] isKindOfClass:[MoveToPathElement class]]){
                        // this happen if the entire stroke lands inside of scraps, and nothing makes it to the bottom page
                        // just save an empty stroke to the stack
                        [currentStroke empty];
                    }
                    [state finishCurrentStroke];
                    
                    [[JotStrokeManager sharedInstance] removeStrokeForTouch:jotTouch.touch];
                    
                    [self.delegate didEndStrokeWithTouch:jotTouch];
                }
                [currentStroke unlock];
                [JotTouch cleanJotTouchFor:touch];
            }
        }
    }
    [JotGLContext validateEmptyContextStack];
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
    CheckMainThread;
    if(!state) return;

    if(![JotStylusManager sharedInstance].isStylusConnected){
        for(UITouch* touch in touches){
            @autoreleasepool {
                // If appropriate, add code necessary to save the state of the application.
                // This application is not saving state.
                JotTouch* jotTouch = [JotTouch jotTouchFor:touch];
                if([[JotStrokeManager sharedInstance] cancelStrokeForTouch:jotTouch.touch]){
                    state.currentStroke = nil;
                }
                [JotTouch cleanJotTouchFor:touch];
            }
        }
        // we need to erase the current stroke from the screen, so
        // clear the canvas and rerender all valid strokes
        [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:CGRectZero];
    }
    [JotGLContext validateEmptyContextStack];
}



#pragma mark - Public Interface


-(BOOL) canUndo{
    return [state canUndo];
}

-(BOOL) canRedo{
    return [state canRedo];
}

/**
 * this will move one of the completed strokes to the undo
 * stack, and then rerender all other completed strokes
 */
-(IBAction) undo{
    CheckMainThread;
    JotStroke* undoneStroke = [state undo];
    [undoneStroke lock];
    if(undoneStroke){
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGRect bounds = [undoneStroke bounds];
        bounds = CGRectApplyAffineTransform(bounds, CGAffineTransformMakeScale(scale, scale));
        [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:bounds];
    }
    [undoneStroke unlock];
}

// helper method to pop the most recent stroke
// off the stack and forget it entirely. it will
// not be able to be redone.
-(void) undoAndForget{
    CheckMainThread;
    JotStroke* lastKnownStroke = [state undoAndForget];
    [lastKnownStroke lock];
    if(lastKnownStroke){
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGRect bounds = [lastKnownStroke bounds];
        bounds = CGRectApplyAffineTransform(bounds, CGAffineTransformMakeScale(scale, scale));
        if([lastKnownStroke.segments count] && !CGSizeEqualToSize(bounds.size, CGSizeZero)){
            // don't bother re-rendering if the stroke was empty to begin with
            [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:bounds];
        }
    }
    [lastKnownStroke unlock];
}

/**
 * if we have undone strokes, then move the most recent
 * undo back to the completed strokes list, then rerender
 */
-(IBAction) redo{
    JotStroke* redoneStroke = [state redo];
    [redoneStroke lock];
    if(redoneStroke){
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGRect bounds = [redoneStroke bounds];
        bounds = CGRectApplyAffineTransform(bounds, CGAffineTransformMakeScale(scale, scale));
        [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:bounds];
    }
    [redoneStroke unlock];
}


/**
 * erase the screen
 */
- (IBAction) clear:(BOOL)shouldPresent{
    CheckMainThread;
    if(!state) return;

    // set our context
    [context runBlock:^{
        [viewFramebuffer clear];
        
        if(shouldPresent){
            // Display the buffer
            [self setNeedsPresentRenderBuffer];
        }
        
        // reset undo state
        [state clearAllStrokes];
    }];
	
    [JotGLContext validateEmptyContextStack];
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
    return [state undoHash];
}

-(CGSize) pagePtSize{
    return initialFrameSize;
}

-(CGFloat) scale{
    return [[UIScreen mainScreen] scale];
}

-(NSInteger) maxCurrentStrokeByteSize{
    return [state.currentStroke fullByteSize];
}

// add an undo level, and create
// fresh empty strokes for any current
// strokes.
// if no current strokes, then add an
// empty stroke to the stack
-(void) addUndoLevelAndContinueStroke{
    [state addUndoLevelAndContinueStrokeWithBrush:[JotDefaultBrushTexture sharedInstance]];
}

-(void) addUndoLevelAndFinishStroke{
    [state addUndoLevelAndFinishStrokeWithBrush:[JotDefaultBrushTexture sharedInstance]];
}

/**
 * this will add all of the input elements to a stroke,
 * and will make sure that the stroke color matches the input
 * elements color.
 *
 * if the most recent stroke is for an eraser, then a new stroke
 * will be built if these input elements are for a pen, etc
 */
-(void) addElements:(NSArray*)elements{
    CheckMainThread;
    if(!state) return;
    
    __block BOOL needsPresent = NO;
    [self.context runBlock:^{
        
        JotStroke* stroke = state.currentStroke;
        BOOL strokeHasColor = [[stroke.segments lastObject] color] != nil;
        BOOL elementsHaveColor = [[elements firstObject] color] != nil;
        
        
        if(!stroke || strokeHasColor != elementsHaveColor || [stroke isKindOfClass:[JotFilledPathStroke class]]){
            if(stroke && strokeHasColor != elementsHaveColor){
                //
                // https://github.com/adamwulf/loose-leaf/issues/249
                //
                // don't allow us to add eraser elements to a pen stroke,
                // or add pen elements to an eraser stroke! otherwise this
                // will create artifacts when saving these strokes to the
                // backing texture.
                //            DebugLog(@"fixed!!!!");
            }
            if(state.currentStroke){
                @throw [NSException exceptionWithName:@"MultipleStrokeException" reason:@"Only 1 stroke is allowed at a time" userInfo:nil];
            }
            stroke = [[JotStroke alloc] initWithTexture:[JotDefaultBrushTexture sharedInstance] andBufferManager:self.state.bufferManager];
            state.currentStroke = stroke;
        }
        [stroke lock];
        [stroke.texture bind];
        
        for(AbstractBezierPathElement* element in elements){
            AbstractBezierPathElement* prevElement = [stroke.segments lastObject];
            
            [stroke addElement:element];
            
            if(![element isKindOfClass:[MoveToPathElement class]]){
                CGRect eleBounds = element.bounds;
                CGRect myBounds = self.bounds;
                if(prevElement && ((!prevElement.color && element.color) ||
                                   (prevElement.color && !element.color))){
                    DebugLog(@"gotcha!");
                }
                if(CGRectIntersectsRect(myBounds, eleBounds)){
                    needsPresent = YES;
                    [self renderElement:element fromPreviousElement:prevElement includeOpenGLPrepForFBO:viewFramebuffer toContext:context];
                }else{
                    DebugLog(@"gotcha?");
                }
            }
        }
        if(needsPresent){
            [self setNeedsPresentRenderBuffer];
        }
        [stroke.texture unbind];
        [stroke unlock];
    }];
}



/**
 * this will add an empty stroke to the jotview,
 * which is useful for force updating the undo history/
 * hash of the view to help trigger a save
 *
 * this is useful particularly when force drawing a texture
 * using drawBackingTexture:atP1:andP2:andP3:andP4: and wanting
 * it to trigger a new undoHash to help with knowing about
 * when to save
 */
-(void) forceAddEmptyStroke{
    [state forceAddEmptyStrokeWithBrush:[JotDefaultBrushTexture sharedInstance]];
}

-(void) forceAddStrokeForFilledPath:(UIBezierPath*)path andP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4 andSize:(CGSize)size{
    CheckMainThread;
    // make sure size is rounded up
    size.width = ceilf(size.width);
    size.height = ceilf(size.height);
    [context runBlock:^{
        JotFilledPathStroke* stroke = [[JotFilledPathStroke alloc] initWithPath:path andP1:p1 andP2:p2 andP3:p3 andP4:p4 andSize:size];
        [state forceAddStroke:stroke];
        
        [stroke.texture bind];
        [self renderElement:[stroke.segments firstObject] fromPreviousElement:nil includeOpenGLPrepForFBO:viewFramebuffer toContext:context];
        [self setNeedsPresentRenderBuffer];
        [stroke.texture unbind];
    }];
}

#pragma mark - dealloc

/**
 * Releases resources when they are not longer needed.
 */
- (void) dealloc
{
    if(isCurrentlyExporting){
        DebugLog(@"what6");
    }
    [self destroyFramebuffer];
}

-(void) willMoveToSuperview:(UIView *)newSuperview{
    if(self.superview && newSuperview){
        // noop, we're already registered
    }else if(self.superview && !newSuperview){
        // unregister
        [[JotStylusManager sharedInstance] unregisterView:self];
    }else if(!self.superview && newSuperview){
        // register
        [[JotStylusManager sharedInstance] registerView:self];
    }else if(!self.superview && !newSuperview){
        // noop
    }
}


#pragma mark - OpenGL

-(JotGLTexture*) generateTexture{
    CheckMainThread;
    __block JotGLTexture* canvasTexture = nil;
    [context runBlock:^{
        CGSize maxTextureSize = [UIScreen mainScreen].portraitBounds.size;
        maxTextureSize.width *= [UIScreen mainScreen].scale;
        maxTextureSize.height *= [UIScreen mainScreen].scale;
        
        CGSize fullSize = CGSizeMake(ceilf(viewFramebuffer.initialViewport.width), ceilf(viewFramebuffer.initialViewport.height));
        
        // create the texture
        // that we'll draw all of our content to
        canvasTexture = [[JotTextureCache sharedManager] generateTextureForContext:context ofSize:maxTextureSize];
        [canvasTexture bind];

        @autoreleasepool {
            JotGLTextureBackedFrameBuffer* exportFramebuffer = [[JotGLTextureBackedFrameBuffer alloc] initForTexture:canvasTexture];
            
            // set viewport to round up to the pixel, if needed
            glViewport(0, 0, fullSize.width, fullSize.height);
            
            // ok, everything is setup at this point, so render all
            // of the strokes over the backing texture to our
            // export texture
            [self renderAllStrokesToContext:context inFramebuffer:exportFramebuffer andPresentBuffer:NO inRect:CGRectZero];
            
            // now all of the content has been pushed to the texture,
            // so delete the framebuffer
            exportFramebuffer = nil;
            [canvasTexture unbind];
        }
        
        // reset back to exact viewport
        glViewport(0, 0, viewFramebuffer.initialViewport.width, viewFramebuffer.initialViewport.height);
        
        // we have to flush here to push all
        // the pixels to the texture so they're
        // available in the background thread's
        // context
        // popping the context will flush
    }];
    
    return canvasTexture;
}




-(void) drawBackingTexture:(JotGLTexture*)texture atP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4 clippingPath:(UIBezierPath*)clipPath andClippingSize:(CGSize)clipSize withTextureSize:(CGSize)textureSize{
    
    [inkTextureLock lock];
    [imageTextureLock lock];
            
            
    CheckMainThread;
    glFlush();
    JotGLContext* subContext = [[JotGLContext alloc] initWithName:@"JotViewDrawBackingTextureContext" andAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:mainThreadContext.sharegroup andValidateThreadWith:^BOOL{
        return [NSThread isMainThread];
    }];
    [subContext runBlock:^{
        // render it to the backing texture
        [state.backgroundFramebuffer bind];
        [self prepOpenGLStateForFBO:state.backgroundFramebuffer toContext:subContext];
        // Setup OpenGL states
        glMatrixMode(GL_PROJECTION);
        // Setup the view port in Pixels
        glMatrixMode(GL_MODELVIEW);
        [subContext glDisableDither];
        [subContext glEnableTextures];
        [subContext glEnableBlend];
        // Set a blending function appropriate for premultiplied alpha pixel data
        [subContext glBlendFunc:GL_ONE and:GL_ONE_MINUS_SRC_ALPHA];
        [context glEnablePointSprites];
        CGRect frame = self.layer.bounds;
        CGFloat scale = self.contentScaleFactor;
        
        CGSize initialViewport = CGSizeMake(frame.size.width * scale, frame.size.height * scale);
        
        glOrthof(0, (GLsizei) initialViewport.width, 0, (GLsizei) initialViewport.height, -1, 1);
        glViewport(0, 0, (GLsizei) initialViewport.width, (GLsizei) initialViewport.height);
        
        [subContext assertCheckFramebuffer];
        
        //
        // step 1:
        // Clear the buffer
        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);
        
        //
        // step 2:
        // load a texture and draw it into a quad
        // that fills the screen
        [texture bind];
        [texture drawInContext:subContext
                          atT1:p1
                         andT2:p2
                         andT3:p3
                         andT4:p4
                          atP1:CGPointMake(0, state.backgroundTexture.pixelSize.height)
                         andP2:CGPointMake(state.backgroundTexture.pixelSize.width, state.backgroundTexture.pixelSize.height)
                         andP3:CGPointMake(0,0)
                         andP4:CGPointMake(state.backgroundTexture.pixelSize.width, 0)
                withResolution:state.backgroundTexture.pixelSize
                       andClip:clipPath
               andClippingSize:clipSize
                       asErase:NO];
        [texture unbind];
        [self unprepOpenGLState];
        [state.backgroundFramebuffer unbind];
    }];

    //
    // we just drew to the backing texture, so be sure
    // to flush all openGL commands, so that when we rebind
    // it'll use the updated texture and won't have any
    // issues of unsynchronized textures.
    [context runBlock:^{
        [viewFramebuffer bind];
        [self prepOpenGLStateForFBO:viewFramebuffer toContext:context];
        [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:CGRectZero];
        [viewFramebuffer unbind];
        // flush after drawing to texture
        glFlush();
    }];
    
    [imageTextureLock unlock];
    [inkTextureLock unlock];
}


@end
