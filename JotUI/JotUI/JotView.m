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
#import "LineToPathElement.h"
#import "CurveToPathElement.h"
#import "UIColor+JotHelper.h"
#import "JotGLTexture.h"
#import "JotGLTextureBackedFrameBuffer.h"
#import "JotDefaultBrushTexture.h"
#import "NSArray+JotMapReduce.h"
#import "UIImage+Resize.h"
#import "JotTrashManager.h"
#import "JotViewState.h"

#import <JotTouchSDK/JotStylusManager.h>


#define kJotDefaultUndoLimit 10
#define kJotValidateUndoTimer .06



@interface JotView (){
    
@private
	// OpenGL names for the renderbuffer and framebuffers used to render to this view
	GLuint viewRenderbuffer, viewFramebuffer;
	
	// OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
	GLuint depthRenderbuffer;

    dispatch_queue_t importExportImageQueue;
    dispatch_queue_t importExportStateQueue;
    
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
}

@end


@implementation JotView

@synthesize delegate;
@synthesize context;

#pragma mark - Initialization

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

    // a queue for import/export operations, to make sure that
    // we always complete an export before we can attempt an import
    importExportImageQueue = dispatch_queue_create("com.milestonemade.looseleaf.importExportImageQueue", DISPATCH_QUEUE_SERIAL);

    importExportStateQueue = dispatch_queue_create("com.milestonemade.looseleaf.importExportStateQueue", DISPATCH_QUEUE_SERIAL);
    
    validateUndoStateTimer = [NSTimer scheduledTimerWithTimeInterval:kJotValidateUndoTimer target:self selector:@selector(validateUndoState) userInfo:nil repeats:YES];
    prevElementForTextureWriting = nil;
    exportLaterInvocations = [NSMutableArray array];

    
    //
    // this view should accept Jot stylus touch events
    [[JotStylusManager sharedInstance] registerView:self];
    [[JotTrashManager sharedInstace] setMaxTickDuration:kJotValidateUndoTimer * 1 / 20];

    // create a default empty state
    state = [[JotViewState alloc] init];
    
    // set our default undo limit
    state.undoLimit = kJotDefaultUndoLimit;
    
    // allow more than 1 finger/stylus to draw at a time
    self.multipleTouchEnabled = YES;
    
    //
    // the remainder is OpenGL initialization
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = NO;
    // In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    
    if (!context || ![EAGLContext setCurrentContext:context]) {
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
    
	[EAGLContext setCurrentContext:context];
	[self destroyFramebuffer];
	[self createFramebuffer];

    return self;
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
    
    glOrthof(0, frame.size.width * scale, 0, frame.size.height * scale, -1, 1);
    glViewport(0, 0, initialViewport.width, initialViewport.height);

	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}
    
    [self clear];
	
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



#pragma mark - Export and Import


-(void) exportInkTo:(NSString*)inkPath
     andThumbnailTo:(NSString*)thumbnailPath
         andPlistTo:(NSString*)plistPath
         onComplete:(void(^)(UIImage* ink, UIImage* thumb, NSDictionary* state))exportFinishBlock{

    CheckMainThread;
    
    if(![state isReadyToExport] || isCurrentlyExporting){
        if(isCurrentlyExporting){
            NSLog(@"cant save, currently exporting");
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
            NSMethodSignature * mySignature = [JotView instanceMethodSignatureForSelector:@selector(exportInkTo:andThumbnailTo:andPlistTo:onComplete:)];
            NSInvocation* saveInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
            [saveInvocation setTarget:self];
            [saveInvocation setSelector:@selector(exportInkTo:andThumbnailTo:andPlistTo:onComplete:)];
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
        NSLog(@"export begins");
    }
    
    dispatch_semaphore_t sema1 = dispatch_semaphore_create(0);
    dispatch_semaphore_t sema2 = dispatch_semaphore_create(0);
    
    __block UIImage* thumb = nil;
    __block UIImage* ink = nil;
    
    //
    // TODO
    // create an immutable state object
    NSMutableDictionary* stateDict = [NSMutableDictionary dictionary];
    [stateDict setObject:[state.stackOfStrokes copy] forKey:@"stackOfStrokes"];
    [stateDict setObject:[state.stackOfUndoneStrokes copy] forKey:@"stackOfUndoneStrokes"];

    [self exportToImageOnComplete:^(UIImage* image){
        thumb = image;
        dispatch_semaphore_signal(sema1);
    }];
    
    [state.backgroundFramebuffer exportTextureOnComplete:^(UIImage* image){
        ink = image;
        dispatch_semaphore_signal(sema2);
    }];
    
    NSLog(@"bg textures saved");

    
    //
    // ok, here i walk off of the main thread,
    // and my state arrays might get changed while
    // i wait (yikes!).
    //
    // i need an immutable state that i can hold onto
    // while i wait + write to disk in the background
    //
    
    dispatch_async(importExportStateQueue, ^(void) {
        dispatch_semaphore_wait(sema1, DISPATCH_TIME_FOREVER);
        // i could notify about the thumbnail here
        // which would let the UI swap to the cached thumbnail
        // from the full JotUI if needed... (?)
        // probably an over optimization at this point,
        // but may be useful once multiple JotViews are
        // on screen at a time + being exported simultaneously
        
        dispatch_semaphore_wait(sema2, DISPATCH_TIME_FOREVER);
        
        exportFinishBlock(ink, thumb, stateDict);
        
        [UIImagePNGRepresentation(ink) writeToFile:inkPath atomically:YES];
        
        [UIImagePNGRepresentation(thumb) writeToFile:thumbnailPath atomically:YES];
        
        [stateDict setObject:[[stateDict objectForKey:@"stackOfStrokes"] jotMapWithSelector:@selector(asDictionary)] forKey:@"stackOfStrokes"];
        [stateDict setObject:[[stateDict objectForKey:@"stackOfUndoneStrokes"] jotMapWithSelector:@selector(asDictionary)] forKey:@"stackOfUndoneStrokes"];

        if(![stateDict writeToFile:plistPath atomically:YES]){
            NSLog(@"couldn't write plist file");
        }
        
        NSLog(@"export complete");
        @synchronized(self){
            isCurrentlyExporting = NO;
        }

    });
}

/**
 * This method will load the input image into the drawable view
 * and will stretch it as appropriate to fill the area. For best results,
 * use an image that is the same size as the view's frame.
 *
 * This method will also reset the undo state of the view.
 *
 * This method must be called at least one time after initialization
 */
-(void) loadImage:(NSString*)inkImageFile andState:(NSString*)stateInfoFile{

    CheckMainThread;

    __block NSDictionary* stateInfo = nil;
    
    // we're going to wait for two background operations to complete
    // using these semaphores
    dispatch_semaphore_t sema1 = dispatch_semaphore_create(0);
    dispatch_semaphore_t sema2 = dispatch_semaphore_create(0);
    
        // the first item is unserializing the plist
        // information for our page state
        dispatch_async(importExportStateQueue, ^{
            
            // load the file
            stateInfo = [NSDictionary dictionaryWithContentsOfFile:stateInfoFile];
            
            //
            // reset our undo state
            [state.strokesBeingWrittenToBackingTexture removeAllObjects];
            [state.stackOfUndoneStrokes removeAllObjects];
            [state.stackOfStrokes removeAllObjects];
            [state.currentStrokes removeAllObjects];
            
            if(stateInfo){
                // load our undo state
                id(^loadStrokeBlock)(id obj, NSUInteger index) = ^id(id obj, NSUInteger index){
                    NSString* className = [obj objectForKey:@"class"];
                    Class class = NSClassFromString(className);
                    JotStroke* stroke = [[class alloc] initFromDictionary:obj];
                    stroke.delegate = self;
                    return stroke;
                };
                
                [state.stackOfStrokes addObjectsFromArray:[[stateInfo objectForKey:@"stackOfStrokes"] jotMap:loadStrokeBlock]];
                [state.stackOfUndoneStrokes addObjectsFromArray:[[stateInfo objectForKey:@"stackOfUndoneStrokes"] jotMap:loadStrokeBlock]];
                
                //
                // sanity check
                for(JotStroke*stroke in [state.stackOfStrokes arrayByAddingObjectsFromArray:state.stackOfUndoneStrokes]){
                    if([stroke.segments count] == 0){
                        [state.stackOfStrokes removeObject:stroke];
                        [state.stackOfUndoneStrokes removeObject:stroke];
                        NSLog(@"oh no!");
                    }
                }
            }else{
                //        NSLog(@"no state info loaded");
            }
            
        dispatch_semaphore_signal(sema1);
    });
    
    // the second item is loading the ink texture
    // into Open GL
    dispatch_async(importExportImageQueue, ^{
        
        EAGLContext* backgroundThreadContext = [[EAGLContext alloc] initWithAPI:context.API sharegroup:context.sharegroup];
        [EAGLContext setCurrentContext:backgroundThreadContext];
        
        // load image from disk
        UIImage* savedInkImage = [UIImage imageWithContentsOfFile:inkImageFile];
        
        // calc final size of the backing texture
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGSize fullPixelSize = CGSizeMake(self.frame.size.width * scale, self.frame.size.height * scale);
        
        // load new texture
        state.backgroundTexture = [[JotGLTexture alloc] initForImage:savedInkImage withSize:fullPixelSize];
        
        if(!savedInkImage){
            // no image was given, so it should be a blank texture
            // lets erase it, since it defaults to uncleared memory
            [state.backgroundFramebuffer clear];
        }
        dispatch_semaphore_signal(sema2);
        glFlush();
    });
    
    // wait here
    // until both above items are complete
    dispatch_semaphore_wait(sema1, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_wait(sema2, DISPATCH_TIME_FOREVER);
    
    //
    // ok, render the new content
    [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:CGRectZero];
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

    if(!exportFinishBlock) return;

    CGSize exportSize = CGSizeMake(initialViewport.width / 2, initialViewport.height / 2);
    
	GLuint exportFramebuffer;
    
	glGenFramebuffersOES(1, &exportFramebuffer);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, exportFramebuffer);
    GLuint canvastexture;
    
    // create the texture
    glGenTextures(1, &canvastexture);
    glBindTexture(GL_TEXTURE_2D, canvastexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,  exportSize.width, exportSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glFramebufferTexture2DOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_TEXTURE_2D, canvastexture, 0);
    
    GLenum status = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
    if(status != GL_FRAMEBUFFER_COMPLETE_OES) {
        NSLog(@"failed to make complete framebuffer object %x", status);
    }
    
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
    
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glViewport(0, 0, exportSize.width, exportSize.height);
    glClear(GL_COLOR_BUFFER_BIT);
    
    [self renderAllStrokesToContext:context inFramebuffer:exportFramebuffer andPresentBuffer:NO inRect:CGRectZero];
    
    // read the image from OpenGL and push it into a data buffer
    NSInteger x = 0, y = 0; //, width = backingWidthForRenderBuffer, height = backingHeightForRenderBuffer;
    NSInteger dataLength = exportSize.width * exportSize.height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(x, y, exportSize.width, exportSize.height, GL_RGBA, GL_UNSIGNED_BYTE, data);

    
    
    glDeleteFramebuffersOES(1, &exportFramebuffer);
    glDeleteTextures(1, &canvastexture);
    
    glViewport(0, 0, initialViewport.width, initialViewport.height);

    
    //
    // the rest can be done in Core Graphics in a background thread
    dispatch_async(importExportImageQueue, ^{
        
        // Create a CGImage with the pixel data from OpenGL
        // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
        // otherwise, use kCGImageAlphaPremultipliedLast
        CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
        CGImageRef iref = CGImageCreate(exportSize.width, exportSize.height, 8, 32, exportSize.width * 4, colorspace, kCGBitmapByteOrderDefault |
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
-(void) renderAllStrokesToContext:(EAGLContext*)renderContext inFramebuffer:(GLuint)theFramebuffer andPresentBuffer:(BOOL)shouldPresent inRect:(CGRect)scissorRect{
    
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
    [EAGLContext setCurrentContext:renderContext];
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
    [state.backgroundTexture draw];
    
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
        [self presentRenderBuffer];
    }
    
    // now that we're done rendering strokes, reset the texture
    // to the current brush
    [self setBrushTexture:keepThisTexture];
    
    if(!CGRectEqualToRect(scissorRect, CGRectZero)){
        glDisable(GL_SCISSOR_TEST);
    }
}


/**
 * this is a simple method to display our renderbuffer
 */
-(void) presentRenderBuffer{
    CheckMainThread;
    
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
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
    if(![currentStroke addPoint:end withWidth:width andColor:color andSmoothness:smoothFactor]) return;
    
    AbstractBezierPathElement* addedElement = [currentStroke.segments lastObject];
    addedElement.rotation = [self.delegate rotationForSegment:addedElement fromPreviousSegment:previousElement];

    //
    // ok, now we have the current + previous stroke segment
    // so let's set to drawing it!
    [self renderElement:addedElement fromPreviousElement:previousElement includeOpenGLPrepForFBO:viewFramebuffer];
    
    // Display the buffer
    [self presentRenderBuffer];
}


/**
 * this renders a single stroke segment to the glcontext.
 *
 * this assumes that this has been called:
 * [EAGLContext setCurrentContext:context];
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
    [EAGLContext setCurrentContext:context];
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, frameBuffer);
    
    // setup our state
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
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
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);
}


/**
 * This method will make sure we only keep undoLimit
 * number of strokes. All others should be written to
 * our backing texture
 */
-(void) validateUndoState{
    
    CheckMainThread;
    
    if([state.stackOfStrokes count] > state.undoLimit){
        while([state.stackOfStrokes count] > state.undoLimit){
            NSLog(@"== eating strokes");
            
            [state.strokesBeingWrittenToBackingTexture addObject:[state.stackOfStrokes objectAtIndex:0]];
            [state.stackOfStrokes removeObjectAtIndex:0];
        }
    }
    if([state.strokesBeingWrittenToBackingTexture count]){
        JotBrushTexture* keepThisTexture = brushTexture;
        // get the stroke that we need to make permanent
        JotStroke* strokeToWriteToTexture = [state.strokesBeingWrittenToBackingTexture objectAtIndex:0];
        
        // render it to the backing texture
        [self prepOpenGLStateForFBO:state.backgroundFramebuffer.framebufferID];
        // reset the texture so that we load the brush texture next
        brushTexture = nil;
        // now draw the strokes
        
        // make sure our texture is the correct one for this stroke
        if(strokeToWriteToTexture.texture != brushTexture){
            [self setBrushTexture:strokeToWriteToTexture.texture];
        }
        // setup our blend mode properly for color vs eraser
        if([strokeToWriteToTexture.segments count]){
            AbstractBezierPathElement* firstElement = [strokeToWriteToTexture.segments objectAtIndex:0];
            [self prepOpenGLBlendModeForColor:firstElement.color];
        }
        
        
        NSDate *date = [NSDate date];

        //
        // draw each stroke element
        int count = 0;
        while([strokeToWriteToTexture.segments count] && ABS([date timeIntervalSinceNow]) < kJotValidateUndoTimer * 1 / 20){
            AbstractBezierPathElement* element = [strokeToWriteToTexture.segments objectAtIndex:0];
            [strokeToWriteToTexture.segments removeObject:element];
            [self renderElement:element fromPreviousElement:prevElementForTextureWriting includeOpenGLPrepForFBO:nil];
            prevElementForTextureWriting = element;
            [[JotTrashManager sharedInstace] addObjectToDealloc:element];
            count++;
        }

        if([strokeToWriteToTexture.segments count] == 0){
            [state.strokesBeingWrittenToBackingTexture removeObject:strokeToWriteToTexture];
            prevElementForTextureWriting = nil;
        }
        
        [self unprepOpenGLState];

        [self setBrushTexture:keepThisTexture];
        
        
        //
        // if the app tries to export while we're writing out
        // strokes to a texture, then it adds an NSInvocation to
        // this array. after we're done validating the undo state
        // then we fire off the save command that has been waiting
        // on us.
        if([strokeToWriteToTexture.segments count] == 0 && [exportLaterInvocations count]){
            NSInvocation* invokation = [exportLaterInvocations objectAtIndex:0];
            [exportLaterInvocations removeObject:invokation];
            [invokation invoke];
        }
    }else if([exportLaterInvocations count]){
        NSInvocation* invokation = [exportLaterInvocations objectAtIndex:0];
        [exportLaterInvocations removeObject:invokation];
        [invokation invoke];
    }else{
        [[JotTrashManager sharedInstace] tick];
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
        }
    }
}

/**
 * Handles the end of a touch event when the touch is a tap.
 */
-(void)jotStylusTouchEnded:(NSSet *) touches{
    
    CheckMainThread;
    
    for(JotTouch* jotTouch in touches){
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


/**
 * this will move one of the completed strokes to the undo
 * stack, and then rerender all other completed strokes
 */
-(IBAction) undo{
    if([state.stackOfStrokes count]){
        CGRect bounds = [[state.stackOfStrokes lastObject] bounds];
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
    if([state.stackOfUndoneStrokes count]){
        CGRect bounds = [[state.stackOfUndoneStrokes lastObject] bounds];
        [state.stackOfStrokes addObject:[state.stackOfUndoneStrokes lastObject]];
        [state.stackOfUndoneStrokes removeLastObject];
        [self renderAllStrokesToContext:context inFramebuffer:viewFramebuffer andPresentBuffer:YES inRect:bounds];
    }
}


/**
 * erase the screen
 */
- (IBAction) clear
{
    // set our context
	[EAGLContext setCurrentContext:context];
	
	// Clear the buffer
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
    
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewRenderbuffer);
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);

    // clear the background
    [state.backgroundFramebuffer clear];

	// Display the buffer
    [self presentRenderBuffer];
    
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
    NSUInteger hashVal = 0;
    for(JotStroke* stroke in state.stackOfStrokes){
        hashVal += [stroke hash];
    }
    for(JotStroke* stroke in state.currentStrokes){
        hashVal += [stroke hash];
    }
    return hashVal;
}


#pragma mark - dealloc

/**
 * Releases resources when they are not longer needed.
 */
- (void) dealloc
{
    [self destroyFramebuffer];
    [[JotStylusManager sharedInstance] unregisterView:self];

	if([EAGLContext currentContext] == context){
		[EAGLContext setCurrentContext:nil];
	}
}


@end
