//
//  Shortcut.h
//  JotSDKLibrary
//
//  Created by Adam Wulf on 11/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

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

#import <JotTouchSDK/JotStylusManager.h>


#define kJotValidateUndoTimer .06
#define kJotMaxStrokeByteSize 256*1024


dispatch_queue_t importExportImageQueue;
dispatch_queue_t importExportStateQueue;


@interface JotView (){
    __weak NSObject<JotViewDelegate>* delegate;
    
	JotGLContext *context;
    
    CGSize initialViewport;
    
@private
	// OpenGL names for the renderbuffer and framebuffers used to render to this view
	GLuint viewRenderbuffer, viewFramebuffer;
	
	// OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
	GLuint depthRenderbuffer;

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
    BOOL isCurrentlyExporting;

    // a handle to the image used as the current brush texture
    __strong JotBrushTexture* brushTexture;
    JotViewState* state;
    
    CGSize initialFrameSize;
    
    // YES if we need to present our renderbuffer on the
    // next display link
    BOOL needsPresentRenderBuffer;
    // YES if we should limit to 30fps, NO otherwise
    BOOL shouldslow;
    // helper var to toggle between frames for 30fps limit
    BOOL slowtoggle;
    // the maximum stroke size in bytes before a new stroke
    // is created
    NSInteger maxStrokeSize;
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
    if((self = [super initWithFrame:frame])){
        return [self finishInit];
    }
    return self;
}

-(id) finishInit{
    
    // strokes have a max of .5Mb each
    self.maxStrokeSize = 512*1024;
    
//    CADisplayLink* displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(presentRenderBuffer)];
//    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

    initialFrameSize = self.bounds.size;
    
    prevElementForTextureWriting = nil;
    exportLaterInvocations = [NSMutableArray array];
    
    validateUndoStateTimer = [NSTimer scheduledTimerWithTimeInterval:kJotValidateUndoTimer
                                                              target:self
                                                            selector:@selector(validateUndoState)
                                                            userInfo:nil
                                                             repeats:YES];

    //
    // this view should accept Jot stylus touch events
    [[JotStylusManager sharedInstance] registerView:self];
    [[JotTrashManager sharedInstace] setMaxTickDuration:kJotValidateUndoTimer * 1 / 20];

    // create a default empty state
    state = [[JotViewState alloc] init];
    
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
        context = [[JotGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        mainThreadContext = context;
    }else{
        context = [[JotGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1 sharegroup:mainThreadContext.sharegroup];
    }
    
    if (!context || ![JotGLContext setCurrentContext:context]) {
        return nil;
    }
    
    [self setBrushTexture:[JotDefaultBrushTexture sharedInstace]];

    // Set the view's scale factor
    self.contentScaleFactor = [[UIScreen mainScreen] scale];
    
    // Setup OpenGL states
    glMatrixMode(GL_PROJECTION);
    
    // Setup the view port in Pixels
    glMatrixMode(GL_MODELVIEW);
    
    glDisable(GL_DITHER);
    glEnable(GL_TEXTURE_2D);
    
    glEnable(GL_BLEND);
    // Set a blending function appropriate for premultiplied alpha pixel data
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    glEnable(GL_POINT_SPRITE_OES);
    glTexEnvf(GL_POINT_SPRITE_OES, GL_COORD_REPLACE_OES, GL_TRUE);
    
	[self destroyFramebuffer];
	[self createFramebuffer];

    return self;
}

#pragma mark - Dispatch Queues

+(dispatch_queue_t) importExportImageQueue{
    if(!importExportImageQueue){
        importExportImageQueue = dispatch_queue_create("com.milestonemade.looseleaf.importExportImageQueue", DISPATCH_QUEUE_SERIAL);
    }
    return importExportImageQueue;
}

+(dispatch_queue_t) importExportStateQueue{
    if(!importExportStateQueue){
        importExportStateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,NULL);
//        dispatch_queue_create("com.milestonemade.looseleaf.importExportStateQueue", DISPATCH_QUEUE_SERIAL);
    }
    return importExportStateQueue;
}



#pragma mark - OpenGL Init



/**
 * this will create the framebuffer and related
 * render and depth buffers that we'll use for
 * drawing
 */
- (BOOL)createFramebuffer{
	// The pixel dimensions of the backbuffer
	GLint backingWidth;
	GLint backingHeight;
	
	// Generate IDs for a framebuffer object and a color renderbuffer
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	// This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
	// allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	// For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
	glGenRenderbuffersOES(1, &depthRenderbuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
	glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
	
    CGRect frame = self.layer.bounds;
    CGFloat scale = self.contentScaleFactor;
    
    initialViewport = CGSizeMake(frame.size.width * scale, frame.size.height * scale);
    
    glOrthof(0, (GLsizei) initialViewport.width, 0, (GLsizei) initialViewport.height, -1, 1);
    glViewport(0, 0, (GLsizei) initialViewport.width, (GLsizei) initialViewport.height);

	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}
    
    
    [self clear:NO];
	
	return YES;
}

/**
 * Clean up any buffers we have allocated.
 */
- (void)destroyFramebuffer{
    if(viewFramebuffer){
        glDeleteFramebuffersOES(1, &viewFramebuffer);
        viewFramebuffer = 0;
    }
    if(viewRenderbuffer){
        glDeleteRenderbuffersOES(1, &viewRenderbuffer);
        viewRenderbuffer = 0;
    }
	if(depthRenderbuffer){
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
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
-(void) loadState:(JotViewState*)newState{
    CheckMainThread;
    if(state != newState){
        state.delegate = nil;
        newState.delegate = self;
        state = newState;
        [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:CGRectZero];
    }
}

-(void) exportImageTo:(NSString*)inkPath
       andThumbnailTo:(NSString*)thumbnailPath
           andStateTo:(NSString*)plistPath
           onComplete:(void(^)(UIImage* ink, UIImage* thumb, JotViewImmutableState* state))exportFinishBlock{
    
    CheckMainThread;
    
    if(![state isReadyToExport] || isCurrentlyExporting){
        if(isCurrentlyExporting){
//            NSLog(@"cant save, currently exporting");
        }
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
        if(![exportLaterInvocations count]){
            void(^block)(UIImage* ink, UIImage* thumb, NSDictionary* state) = [exportFinishBlock copy];
            NSMethodSignature * mySignature = [JotView instanceMethodSignatureForSelector:@selector(exportImageTo:andThumbnailTo:andStateTo:onComplete:)];
            NSInvocation* saveInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
            [saveInvocation setTarget:self];
            [saveInvocation setSelector:@selector(exportImageTo:andThumbnailTo:andStateTo:onComplete:)];
            [saveInvocation setArgument:&inkPath atIndex:2];
            [saveInvocation setArgument:&thumbnailPath atIndex:3];
            [saveInvocation setArgument:&plistPath atIndex:4];
            [saveInvocation setArgument:&block atIndex:5];
            [saveInvocation retainArguments];
            [exportLaterInvocations addObject:saveInvocation];
        }
        return;
    }
    
    @synchronized(self){
        isCurrentlyExporting = YES;
        NSLog(@"export begins: %@", [NSDate date]);
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
    
//    NSLog(@"saving begins with hash: %u vs %u", [immutableState undoHash], [self undoHash]);
    
    
//    [state.backgroundFramebuffer exportTextureOnComplete:^(UIImage* image){
//        ink = image;
//        dispatch_semaphore_signal(sema2);
//    }];
    
    [self exportInkTextureOnComplete:^(UIImage* image){
        ink = image;
        dispatch_semaphore_signal(sema2);
    }];
    

    // now grab the bits of the rendered thumbnail
    // and backing texture
    [self exportToImageOnComplete:^(UIImage* image){
        thumb = image;
        dispatch_semaphore_signal(sema1);
    }];
    
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
            
            exportFinishBlock(ink, thumb, immutableState);
            
            if(ink){
                // we have the backing ink texture to save
                // so write it to disk
                [UIImagePNGRepresentation(ink) writeToFile:inkPath atomically:YES];
                //            NSLog(@"writing ink to disk");
            }else{
                // the backing texture either hasn't changed, or
                // doesn't have anything written to it at all
                // so skip writing a blank PNG to disk
                //            NSLog(@"skipping writing ink, nothing changed");
            }
            
            [UIImagePNGRepresentation(thumb) writeToFile:thumbnailPath atomically:YES];
            
            // this call will both serialize the state
            // and write it to disk
            [immutableState writeToDisk:plistPath];
            
            //        NSLog(@"export complete");
            @synchronized(self){
                // we only ever want to export one at a time.
                // if anything has changed while we've been exporting
                // then that'll be held in the exportLaterInvocations
                // and will fire after we're done. (from validateUndoState).
                isCurrentlyExporting = NO;
            }
            NSLog(@"export ends: %@", [NSDate date]);
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
-(void) exportToImageOnComplete:(void(^)(UIImage*) )exportFinishBlock{
    
    CheckMainThread;
    
    if([JotGLContext currentContext] != context){
        glFlush();
        [JotGLContext setCurrentContext:context];
    }

    if(!exportFinishBlock) return;

    CGSize fullSize = CGSizeMake(initialViewport.width, initialViewport.height);
    CGSize exportSize = CGSizeMake(initialViewport.width / 2, initialViewport.height / 2);
    
	GLuint exportFramebuffer;
    
    glGenFramebuffersOES(1, &exportFramebuffer);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, exportFramebuffer);
    GLuint canvastexture;
    
    // create the texture
    glGenTextures(1, &canvastexture);
    glBindTexture(GL_TEXTURE_2D, canvastexture);
    
    //
    // http://stackoverflow.com/questions/5835656/glframebuffertexture2d-fails-on-iphone-for-certain-texture-sizes
    // these are required for non power of 2 textures on iPad 1 version of OpenGL1.1
    // otherwise, the glCheckFramebufferStatusOES will be GL_FRAMEBUFFER_UNSUPPORTED_OES
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,  fullSize.width, fullSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, canvastexture, 0);
    
    GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
    if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
        NSLog(@"failed to make complete framebuffer object %x", status);
    }
    
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glViewport(0, 0, fullSize.width, fullSize.height);
    glClear(GL_COLOR_BUFFER_BIT);
    
    [self renderAllStrokesToContext:context inFramebuffer:exportFramebuffer andPresentBuffer:NO inRect:CGRectZero];
    
    // read the image from OpenGL and push it into a data buffer
    NSInteger x = 0, y = 0; //, width = backingWidthForRenderBuffer, height = backingHeightForRenderBuffer;
    NSInteger dataLength = fullSize.width * fullSize.height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(x, y, fullSize.width, fullSize.height, GL_RGBA, GL_UNSIGNED_BYTE, data);

    
    
    glDeleteFramebuffersOES(1, &exportFramebuffer);
    glDeleteTextures(1, &canvastexture);
    
    if([JotGLContext currentContext] != context){
        glFlush();
        [JotGLContext setCurrentContext:context];
    }
    
    glViewport(0, 0, initialViewport.width, initialViewport.height);

    
    //
    // the rest can be done in Core Graphics in a background thread
    dispatch_async(importExportImageQueue, ^{
        @autoreleasepool {
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
            CGContextRef bitmapContext = CGBitmapContextCreate(NULL, exportSize.width, exportSize.height, 8, exportSize.width * 4, colorspace, kCGBitmapByteOrderDefault |
                                                               kCGImageAlphaPremultipliedLast);
            
            // flip vertical for our drawn content, since OpenGL is opposite core graphics
            CGContextTranslateCTM(bitmapContext, 0, exportSize.height);
            CGContextScaleCTM(bitmapContext, 1.0, -1.0);
            
            //
            // ok, now render our actual content
            CGContextDrawImage(bitmapContext, CGRectMake(0.0, 0.0, exportSize.width, exportSize.height), iref);
            
            // Retrieve the UIImage from the current context
            CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
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
    
    if([JotGLContext currentContext] != context){
        glFlush();
        [JotGLContext setCurrentContext:context];
    }
    
    if(!exportFinishBlock) return;
    
    CGSize fullSize = CGSizeMake(initialViewport.width, initialViewport.height);
    CGSize exportSize = CGSizeMake(initialViewport.width, initialViewport.height);
    
	GLuint exportFramebuffer;
    
    glGenFramebuffersOES(1, &exportFramebuffer);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, exportFramebuffer);
    GLuint canvastexture;
    
    // create the texture
    glGenTextures(1, &canvastexture);
    glBindTexture(GL_TEXTURE_2D, canvastexture);
    
    //
    // http://stackoverflow.com/questions/5835656/glframebuffertexture2d-fails-on-iphone-for-certain-texture-sizes
    // these are required for non power of 2 textures on iPad 1 version of OpenGL1.1
    // otherwise, the glCheckFramebufferStatusOES will be GL_FRAMEBUFFER_UNSUPPORTED_OES
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,  fullSize.width, fullSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, canvastexture, 0);
    
    GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
    if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
        NSLog(@"failed to make complete framebuffer object %x", status);
    }
    
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glViewport(0, 0, fullSize.width, fullSize.height);
    glClear(GL_COLOR_BUFFER_BIT);
    
    
    
    // set our current OpenGL context
    if([JotGLContext currentContext] != context){
        glFlush();
        [JotGLContext setCurrentContext:context];
    }
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, exportFramebuffer);
    
	//
    // step 1:
    // Clear the buffer
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
    
    //
    // step 2:
    // load a texture and draw it into a quad
    // that fills the screen
    [state.backgroundTexture drawInContext:context];

    
    
    
    
    // read the image from OpenGL and push it into a data buffer
    NSInteger x = 0, y = 0; //, width = backingWidthForRenderBuffer, height = backingHeightForRenderBuffer;
    NSInteger dataLength = fullSize.width * fullSize.height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(x, y, fullSize.width, fullSize.height, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    
    
    glDeleteFramebuffersOES(1, &exportFramebuffer);
    glDeleteTextures(1, &canvastexture);
    
    if([JotGLContext currentContext] != context){
        glFlush();
        [JotGLContext setCurrentContext:context];
    }
    
    glViewport(0, 0, initialViewport.width, initialViewport.height);
    
    
    //
    // the rest can be done in Core Graphics in a background thread
    dispatch_async(importExportImageQueue, ^{
        @autoreleasepool {
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
            CGContextRef bitmapContext = CGBitmapContextCreate(NULL, exportSize.width, exportSize.height, 8, exportSize.width * 4, colorspace, kCGBitmapByteOrderDefault |
                                                               kCGImageAlphaPremultipliedLast);
            
            // flip vertical for our drawn content, since OpenGL is opposite core graphics
            CGContextTranslateCTM(bitmapContext, 0, exportSize.height);
            CGContextScaleCTM(bitmapContext, 1.0, -1.0);
            
            //
            // ok, now render our actual content
            CGContextDrawImage(bitmapContext, CGRectMake(0.0, 0.0, exportSize.width, exportSize.height), iref);
            
            // Retrieve the UIImage from the current context
            CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
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
-(void) renderAllStrokesToContext:(JotGLContext*)renderContext inFramebuffer:(GLuint)theFramebuffer andPresentBuffer:(BOOL)shouldPresent inRect:(CGRect)scissorRect{
    
    CheckMainThread;

    if(!CGRectEqualToRect(scissorRect, CGRectZero)){
        glEnable(GL_SCISSOR_TEST);
        glScissor(scissorRect.origin.x, scissorRect.origin.y, scissorRect.size.width, scissorRect.size.height);
    }else{
        // noop for scissors
    }
    
    //
    // hang onto the current texture
    // so we can reset it after we draw
    // the strokes
    JotBrushTexture* keepThisTexture = brushTexture;
    
    // set our current OpenGL context
    if([JotGLContext currentContext] != renderContext){
        glFlush();
        [JotGLContext setCurrentContext:renderContext];
    }
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, theFramebuffer);

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
    
    //
    // ok, we're done rendering the background texture to the quad
    //
    
    //
    // step 3:
    // draw all the strokes that we have in our undo-able stack
    [self prepOpenGLStateForFBO:theFramebuffer];
    // reset the texture so that we load the brush texture next
    brushTexture = nil;
    // now draw the strokes
    
    for(JotStroke* stroke in [state everyVisibleStroke]){
        // make sure our texture is the correct one for this stroke
        if(stroke.texture != brushTexture){
            [self setBrushTexture:stroke.texture];
        }
        // setup our blend mode properly for color vs eraser
        if([stroke.segments count]){
            AbstractBezierPathElement* firstElement = [stroke.segments objectAtIndex:0];
            [self prepOpenGLBlendModeForColor:firstElement.color];
        }
        
        // draw each stroke element
        AbstractBezierPathElement* prevElement = nil;
        for(AbstractBezierPathElement* element in stroke.segments){
            [self renderElement:element fromPreviousElement:prevElement includeOpenGLPrepForFBO:nil];
            prevElement = element;
        }
    }
    [self unprepOpenGLState];
    
    if(shouldPresent){
        // step 4:
        // ok, show it!
        [self setNeedsPresentRenderBuffer];
    }
    
    // now that we're done rendering strokes, reset the texture
    // to the current brush
    [self setBrushTexture:keepThisTexture];
    
    if(!CGRectEqualToRect(scissorRect, CGRectZero)){
        glDisable(GL_SCISSOR_TEST);
    }
}


/**
 * cut our framerate by half
 */
-(void) slowDownFPS{
    shouldslow = YES;
}
/**
 * call this to unlimit our FPS back to
 * the full hardware limit
 */
-(void) speedUpFPS{
    shouldslow = NO;
}

/**
 * this is a simple method to display our renderbuffer
 */
-(void) presentRenderBuffer{
    CheckMainThread;
    
    if([JotGLContext currentContext] != self.context){
        glFlush();
        [JotGLContext setCurrentContext:self.context];
    }
    
    if(needsPresentRenderBuffer && (!shouldslow || slowtoggle)){
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
        [context presentRenderbuffer:GL_RENDERBUFFER_OES];
        needsPresentRenderBuffer = NO;
    }
    slowtoggle = !slowtoggle;
}

-(void) setNeedsPresentRenderBuffer{
    needsPresentRenderBuffer = YES;
    [self presentRenderBuffer];
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
- (void) addLineToAndRenderStroke:(JotStroke*)currentStroke toPoint:(CGPoint)end toWidth:(CGFloat)width toColor:(UIColor*)color andSmoothness:(CGFloat)smoothFactor{
    
    CheckMainThread;
    
    // fetch the current and previous elements
    // of the stroke. these will help us
    // step over their length for drawing
    AbstractBezierPathElement* previousElement = [currentStroke.segments lastObject];
    
    // Convert touch point from UIView referential to OpenGL one (upside-down flip)
    end.y = self.bounds.size.height - end.y;
    

    // add the segment to the stroke if we can
    AbstractBezierPathElement* addedElement = [currentStroke.segmentSmoother addPoint:end andSmoothness:smoothFactor];
    // a new element wasn't possible, so just bail here.
    if(!addedElement) return;
    // ok, we have the new element, set its color/width/rotation
    addedElement.color = color;
    addedElement.width = width;
    addedElement.rotation = [self.delegate rotationForSegment:addedElement fromPreviousSegment:previousElement];
    // now tell the stroke that it's added

    // let our delegate have an opportunity to modify the element array
    NSArray* elements = [self.delegate willAddElementsToStroke:[NSArray arrayWithObject:addedElement] fromPreviousElement:previousElement];
    
    // prepend the previous element, so that each of our new elements has a previous element to
    // render with
    elements = [[NSArray arrayWithObject:(previousElement ? previousElement : [NSNull null])] arrayByAddingObjectsFromArray:elements];
    for(int i=1;i<[elements count];i++){
        [currentStroke addElement:[elements objectAtIndex:i]];
        // ok, now we have the current + previous stroke segment
        // so let's set to drawing it!
        [self renderElement:[elements objectAtIndex:i] fromPreviousElement:[elements objectAtIndex:i-1] includeOpenGLPrepForFBO:viewFramebuffer];
    }
    
    // Display the buffer
    [self setNeedsPresentRenderBuffer];
}


/**
 * this renders a single stroke segment to the glcontext.
 *
 * this assumes that this has been called:
 * [JotGLContext setCurrentContext:context];
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
-(void) renderElement:(AbstractBezierPathElement*)element fromPreviousElement:(AbstractBezierPathElement*)previousElement includeOpenGLPrepForFBO:(GLuint)frameBuffer{
    if(frameBuffer){
        // draw the stroke element
        [self prepOpenGLStateForFBO:frameBuffer];
        [self prepOpenGLBlendModeForColor:element.color];
    }
    
    if([[NSNull null] isEqual:previousElement]){
        previousElement = nil;
    }
    
    // find our screen scale so that we can convert from
    // points to pixels
    CGFloat scale = self.contentScaleFactor;
        
    // fetch the vertex data from the element
    [element generatedVertexArrayWithPreviousElement:previousElement forScale:scale];

    // now bind and draw the element
    [element draw];
    
    if(frameBuffer){
        [self unprepOpenGLState];
    }
}

/**
 * this will prepare the OpenGL state to draw
 * a Vertex array for all of the points along
 * the line. each of our vertices contains the
 * point location, color info, and the size
 */
-(void) prepOpenGLStateForFBO:(GLuint)frameBuffer{
    // set to current context
    if([JotGLContext currentContext] != context){
        glFlush();
        [JotGLContext setCurrentContext:context];
    }
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, frameBuffer);
    
    [context glEnableClientState:GL_VERTEX_ARRAY];
    [context glEnableClientState:GL_COLOR_ARRAY];
    [context glEnableClientState:GL_POINT_SIZE_ARRAY_OES];
    [context glDisableClientState:GL_TEXTURE_COORD_ARRAY];
}

/**
 * sets up the blend mode
 * for normal vs eraser drawing
 */
-(void) prepOpenGLBlendModeForColor:(UIColor*)color{
    if(!color){
        // eraser
        glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_ALPHA);
    }else{
        // normal brush
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }
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
-(void) validateUndoState{
    
    CheckMainThread;

    // ticking the state will make sure that the state is valid,
    // containing only the correct number of undoable items in its
    // arrays, and putting all excess strokes into strokesBeingWrittenToBackingTexture
    [state tick];
    
    if([state.strokesBeingWrittenToBackingTexture count]){
        undoCounter++;
        if(undoCounter % 3 == 0){
            NSLog(@"strokes waiting to write: %d", [state.strokesBeingWrittenToBackingTexture count]);
            undoCounter = 0;
        }
        JotBrushTexture* keepThisTexture = brushTexture;
        // get the stroke that we need to make permanent
        JotStroke* strokeToWriteToTexture = [state.strokesBeingWrittenToBackingTexture objectAtIndex:0];
        
        if([JotGLContext currentContext] != context){
            NSLog(@"what");
        }
        // render it to the backing texture
        [self prepOpenGLStateForFBO:state.backgroundFramebuffer.framebufferID];
        [state.backgroundFramebuffer willRenderToFrameBuffer];

        // set our brush texture if needed
        [self setBrushTexture:strokeToWriteToTexture.texture];

        // setup our blend mode properly for color vs eraser
        if([strokeToWriteToTexture.segments count]){
            AbstractBezierPathElement* firstElement = [strokeToWriteToTexture.segments objectAtIndex:0];
            [self prepOpenGLBlendModeForColor:firstElement.color];
        }
        
        // draw each stroke element. for performance reasons, we'll only
        // draw ~ 300 pixels of segments at a time.
        NSInteger distance = 0;
        while([strokeToWriteToTexture.segments count] && distance < 300){
            AbstractBezierPathElement* element = [strokeToWriteToTexture.segments objectAtIndex:0];
            [strokeToWriteToTexture removeElementAtIndex:0];
            [self renderElement:element fromPreviousElement:prevElementForTextureWriting includeOpenGLPrepForFBO:nil];
            prevElementForTextureWriting = element;
            distance += [element lengthOfElement];
            // this should dealloc the element immediately,
            // and the VBO its using internally will be recycled
            // in to the JotBufferManager
        }

        // now that we're done with the stroke,
        // let's throw it in the trash
        if([strokeToWriteToTexture.segments count] == 0){
            [state.strokesBeingWrittenToBackingTexture removeObject:strokeToWriteToTexture];
            [[JotTrashManager sharedInstace] addObjectToDealloc:strokeToWriteToTexture];
            prevElementForTextureWriting = nil;
        }
        
        [self unprepOpenGLState];

        [self setBrushTexture:keepThisTexture];
        //
        // we just drew to the backing texture, so be sure
        // to flush all openGL commands, so that when we rebind
        // it'll use the updated texture and won't have any
        // issues of unsynchronized textures.
        glFlush();
    }else if([state isReadyToExport]){
        // only export if the trash manager is empty
        // that way we're exporting w/ low memory instead
        // of unknown memory
        if(![[JotTrashManager sharedInstace] tick]){
            // ok, the trash is empty, so now see if we need to export
            if([exportLaterInvocations count]){
                NSInvocation* invokation = [exportLaterInvocations objectAtIndex:0];
                [exportLaterInvocations removeObject:invokation];
                [invokation invoke];
            }
        }
    }
}


#pragma mark - JotStrokeDelegate

-(void) jotStrokeWasCancelled:(JotStroke*)stroke{

    CheckMainThread;
    
    for(id key in [state.currentStrokes allKeys]){
        JotStroke* aStroke = [state.currentStrokes objectForKey:key];
        if(aStroke == stroke){
            [state.currentStrokes removeObjectForKey:key];
            [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:stroke.bounds];
            return;
        }
    }
}


#pragma mark - JotPalmRejectionDelegate

/**
 * Handles the start of a touch
 */
-(void)jotStylusTouchBegan:(NSSet *) touches{
    
    CheckMainThread;
    
    for(JotTouch* jotTouch in touches){
        if([self.delegate willBeginStrokeWithTouch:jotTouch]){
            JotStroke* newStroke = [[JotStrokeManager sharedInstace] makeStrokeForTouchHash:jotTouch.touch andTexture:brushTexture];
            newStroke.delegate = self;
            [state.currentStrokes setObject:newStroke forKey:@(jotTouch.touch.hash)];
            // find the stroke that we're modifying, and then add an element and render it
            [self addLineToAndRenderStroke:newStroke
                                   toPoint:[jotTouch locationInView:self]
                                   toWidth:[self.delegate widthForTouch:jotTouch]
                                   toColor:[self.delegate colorForTouch:jotTouch]
                             andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
        }
    }
}

/**
 * Handles the continuation of a touch.
 */
-(void)jotStylusTouchMoved:(NSSet *) touches{
    
    CheckMainThread;
    
    for(JotTouch* jotTouch in touches){
        [self.delegate willMoveStrokeWithTouch:jotTouch];
        JotStroke* currentStroke = [[JotStrokeManager sharedInstace] getStrokeForTouchHash:jotTouch.touch];
        if(currentStroke){
            // find the stroke that we're modifying, and then add an element and render it
            [self addLineToAndRenderStroke:currentStroke
                                   toPoint:[jotTouch locationInView:self]
                                   toWidth:[self.delegate widthForTouch:jotTouch]
                                   toColor:[self.delegate colorForTouch:jotTouch]
                             andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
            if([currentStroke totalNumberOfBytes] > kJotMaxStrokeByteSize){ // 0.25Mb
                NSLog(@"stroke size: %d", [currentStroke totalNumberOfBytes]);
                
                // we'll split the stroke here
                [state.stackOfStrokes addObject:currentStroke];
                [state.currentStrokes removeObjectForKey:@(jotTouch.touch.hash)];
                [state.stackOfUndoneStrokes removeAllObjects];
                [[JotStrokeManager sharedInstace] removeStrokeForTouch:jotTouch.touch];

                // now make a new stroke to pick up where we left off
                JotStroke* newStroke = [[JotStrokeManager sharedInstace] makeStrokeForTouchHash:jotTouch.touch andTexture:brushTexture];
                [state.currentStrokes setObject:newStroke forKey:@(jotTouch.touch.hash)];
                [newStroke.segmentSmoother copyStateFrom:currentStroke.segmentSmoother];
                MoveToPathElement* moveTo = [MoveToPathElement elementWithMoveTo:[[currentStroke.segments lastObject] endPoint]];
                moveTo.width = [(AbstractBezierPathElement*)[currentStroke.segments lastObject] width];
                moveTo.color = [(AbstractBezierPathElement*)[currentStroke.segments lastObject] color];
                moveTo.rotation = [[currentStroke.segments lastObject] rotation];
                [newStroke addElement:moveTo];
            };
        }
    }
}

/**
 * Handles the end of a touch event when the touch is a tap.
 */
-(void)jotStylusTouchEnded:(NSSet *) touches{
    
    CheckMainThread;
    
    for(JotTouch* jotTouch in touches){
        [self.delegate willEndStrokeWithTouch:jotTouch];
        JotStroke* currentStroke = [[JotStrokeManager sharedInstace] getStrokeForTouchHash:jotTouch.touch];
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
            if([currentStroke.segments count] == 0){
                NSLog(@"zero segments!");
            }
            [state.stackOfStrokes addObject:currentStroke];
            [state.currentStrokes removeObjectForKey:@(jotTouch.touch.hash)];
            [state.stackOfUndoneStrokes removeAllObjects];

            [[JotStrokeManager sharedInstace] removeStrokeForTouch:jotTouch.touch];
            
            [self.delegate didEndStrokeWithTouch:jotTouch];
        }
    }
}

/**
 * Handles the end of a touch event.
 */
-(void)jotStylusTouchCancelled:(NSSet *) touches{
    
    CheckMainThread;
    
    for(JotTouch* jotTouch in touches){
        // If appropriate, add code necessary to save the state of the application.
        // This application is not saving state.
        if([[JotStrokeManager sharedInstace] cancelStrokeForTouch:jotTouch.touch]){
            [self.delegate didCancelStrokeWithTouch:jotTouch];
            [state.currentStrokes removeObjectForKey:@(jotTouch.touch.hash)];
        }
    }
    // we need to erase the current stroke from the screen, so
    // clear the canvas and rerender all valid strokes
    [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:CGRectZero];
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
    if(![JotStylusManager sharedInstance].enabled){
        for (UITouch *touch in touches) {
            JotTouch* jotTouch = [JotTouch jotTouchFor:touch];
            if([self.delegate willBeginStrokeWithTouch:jotTouch]){
                JotStroke* newStroke = [[JotStrokeManager sharedInstace] makeStrokeForTouchHash:jotTouch.touch andTexture:brushTexture];
                newStroke.delegate = self;
                [state.currentStrokes setObject:newStroke forKey:@(jotTouch.touch.hash)];
                [self addLineToAndRenderStroke:newStroke
                                       toPoint:[touch locationInView:self]
                                       toWidth:[self.delegate widthForTouch:jotTouch]
                                       toColor:[self.delegate colorForTouch:jotTouch]
                                 andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
            }
        }
    }
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    if(![JotStylusManager sharedInstance].enabled){
        for (UITouch *touch in touches) {
            // check for other brands of stylus,
            // or process non-Jot touches
            //
            // for this example, we'll simply draw every touch if
            // the jot sdk is not enabled
            JotTouch* jotTouch = [JotTouch jotTouchFor:touch];
            JotStroke* currentStroke = [[JotStrokeManager sharedInstace] getStrokeForTouchHash:jotTouch.touch];
            if(currentStroke){
                [self.delegate willMoveStrokeWithTouch:jotTouch];
                [self addLineToAndRenderStroke:currentStroke
                                       toPoint:[touch locationInView:self]
                                       toWidth:[self.delegate widthForTouch:jotTouch]
                                       toColor:[self.delegate colorForTouch:jotTouch]
                                 andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
                if([currentStroke totalNumberOfBytes] > kJotMaxStrokeByteSize){ // 0.25Mb
                    NSLog(@"stroke size: %d", [currentStroke totalNumberOfBytes]);
                    
                    // we'll split the stroke here
                    [state.stackOfStrokes addObject:currentStroke];
                    [state.currentStrokes removeObjectForKey:@(jotTouch.touch.hash)];
                    [state.stackOfUndoneStrokes removeAllObjects];
                    [[JotStrokeManager sharedInstace] removeStrokeForTouch:jotTouch.touch];
                    
                    // now make a new stroke to pick up where we left off
                    JotStroke* newStroke = [[JotStrokeManager sharedInstace] makeStrokeForTouchHash:jotTouch.touch andTexture:brushTexture];
                    [state.currentStrokes setObject:newStroke forKey:@(jotTouch.touch.hash)];
                    [newStroke.segmentSmoother copyStateFrom:currentStroke.segmentSmoother];
                    MoveToPathElement* moveTo = [MoveToPathElement elementWithMoveTo:[[currentStroke.segments lastObject] endPoint]];
                    moveTo.width = [(AbstractBezierPathElement*)[currentStroke.segments lastObject] width];
                    moveTo.color = [(AbstractBezierPathElement*)[currentStroke.segments lastObject] color];
                    moveTo.rotation = [[currentStroke.segments lastObject] rotation];
                    [newStroke addElement:moveTo];
                };
            }
        }
    }
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    if(![JotStylusManager sharedInstance].enabled){
        for(UITouch* touch in touches){
            
            // now line to the end of the stroke
            JotTouch* jotTouch = [JotTouch jotTouchFor:touch];
            JotStroke* currentStroke = [[JotStrokeManager sharedInstace] getStrokeForTouchHash:jotTouch.touch];
            if(currentStroke){
                [self addLineToAndRenderStroke:currentStroke
                                       toPoint:[touch locationInView:self]
                                       toWidth:[self.delegate widthForTouch:jotTouch]
                                       toColor:[self.delegate colorForTouch:jotTouch]
                                 andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
                
                // make sure to add the dot if its just
                // a single tap
                if([currentStroke.segments count] == 1){
                    [self addLineToAndRenderStroke:currentStroke
                                           toPoint:[touch locationInView:self]
                                           toWidth:[self.delegate widthForTouch:jotTouch]
                                           toColor:[self.delegate colorForTouch:jotTouch]
                                     andSmoothness:[self.delegate smoothnessForTouch:jotTouch]];
                }
                
                [self.delegate didEndStrokeWithTouch:jotTouch];
                
                // this stroke is now finished, so add it to our completed strokes stack
                // and remove it from the current strokes, and reset our undo state if any
                if([currentStroke.segments count] == 0){
                    NSLog(@"zero segments!");
                }
                [state.stackOfStrokes addObject:currentStroke];
                [state.currentStrokes removeObjectForKey:@(jotTouch.touch.hash)];
                [state.stackOfUndoneStrokes removeAllObjects];
            }
        }
    }
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
    if(![JotStylusManager sharedInstance].enabled){
        for(UITouch* touch in touches){
            // If appropriate, add code necessary to save the state of the application.
            // This application is not saving state.
            JotTouch* jotTouch = [JotTouch jotTouchFor:touch];
            if([[JotStrokeManager sharedInstace] cancelStrokeForTouch:jotTouch.touch]){
                [self.delegate didCancelStrokeWithTouch:jotTouch];
                [state.currentStrokes removeObjectForKey:@(jotTouch.touch.hash)];
            }
        }
        // we need to erase the current stroke from the screen, so
        // clear the canvas and rerender all valid strokes
        [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:CGRectZero];
    }
}



#pragma mark - Public Interface

-(JotBrushTexture*)brushTexture{
    return brushTexture;
}

/**
 * setup the texture to use for the next brush stroke
 */
-(void) setBrushTexture:(JotBrushTexture*)brushImage{
    if(brushTexture != brushImage){
        [brushTexture unbind];
        brushTexture = brushImage;
        [brushTexture bind];
    }
}

-(BOOL) canUndo{
    return [state.stackOfStrokes count] > 0;
}

-(BOOL) canRedo{
    return [state.stackOfUndoneStrokes count] > 0;
}

/**
 * this will move one of the completed strokes to the undo
 * stack, and then rerender all other completed strokes
 */
-(IBAction) undo{
    if([self canUndo]){
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGRect bounds = [[state.stackOfStrokes lastObject] bounds];
        bounds = CGRectApplyAffineTransform(bounds, CGAffineTransformMakeScale(scale, scale));
        [state.stackOfUndoneStrokes addObject:[state.stackOfStrokes lastObject]];
        [state.stackOfStrokes removeLastObject];
        [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:bounds];
    }
}

/**
 * if we have undone strokes, then move the most recent
 * undo back to the completed strokes list, then rerender
 */
-(IBAction) redo{
    if([self canRedo]){
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGRect bounds = [[state.stackOfUndoneStrokes lastObject] bounds];
        bounds = CGRectApplyAffineTransform(bounds, CGAffineTransformMakeScale(scale, scale));
        [state.stackOfStrokes addObject:[state.stackOfUndoneStrokes lastObject]];
        [state.stackOfUndoneStrokes removeLastObject];
        [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:bounds];
    }
}


/**
 * erase the screen
 */
- (IBAction) clear:(BOOL)shouldPresent{
    // set our context
    glFlush();
	[JotGLContext setCurrentContext:context];
	
	// Clear the buffer
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);

    
    // clear the background
    [state.backgroundFramebuffer clear];

    if(shouldPresent){
        // Display the buffer
        [self setNeedsPresentRenderBuffer];
    }
    
    // reset undo state
    [state.stackOfUndoneStrokes removeAllObjects];
    [state.stackOfStrokes removeAllObjects];
    [state.currentStrokes removeAllObjects];
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

-(CGSize) pagePixelSize{
    // calc final size of the backing texture
    CGFloat scale = [[UIScreen mainScreen] scale];
    return CGSizeMake(initialFrameSize.width * scale, initialFrameSize.height * scale);
}


-(void) addElement:(AbstractBezierPathElement*)element{
    glFlush();
    [JotGLContext setCurrentContext:self.context];
    glViewport(0, 0, initialViewport.width, initialViewport.height);
    JotStroke* stroke = [state.stackOfStrokes lastObject];
    if(!stroke){
        stroke = [[JotStroke alloc] init];
        [state.stackOfStrokes addObject:stroke];
    }
    [stroke addElement:element];
    MoveToPathElement* moveTo = [MoveToPathElement elementWithMoveTo:element.startPoint];
    moveTo.width = element.width;
    moveTo.color = element.color;
    [self renderElement:element fromPreviousElement:moveTo includeOpenGLPrepForFBO:viewFramebuffer];
    [self setNeedsPresentRenderBuffer];
}


#pragma mark - dealloc

/**
 * Releases resources when they are not longer needed.
 */
- (void) dealloc
{
    [self destroyFramebuffer];
    [[JotStylusManager sharedInstance] unregisterView:self];

	if([JotGLContext currentContext] == context){
        glFlush();
		[JotGLContext setCurrentContext:nil];
	}
}


@end
