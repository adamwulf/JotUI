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

#import <JotTouchSDK/JotStylusManager.h>


#define kJotDefaultUndoLimit 10


@interface JotView ()
{
    
@private
    JotGLTexture* backgroundTexture;
    JotGLTextureBackedFrameBuffer* backgroundFramebuffer;
    
	// The pixel dimensions of the backbuffer
	GLint backingWidth;
	GLint backingHeight;
	
	// OpenGL names for the renderbuffer and framebuffers used to render to this view
	GLuint viewRenderbuffer, viewFramebuffer;
	
	// OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
	GLuint depthRenderbuffer;
    
	// OpenGL texure for the brush
	GLuint	glBrushTextureID;
    
    // this dictionary will hold all of the in progress
    // stroke objects
    __strong NSMutableDictionary* currentStrokes;
    
    // these arrays will act as stacks for our undo state
    __strong NSMutableArray* stackOfStrokes;
    __strong NSMutableArray* stackOfUndoneStrokes;
    
    // a handle to the image used as the current brush texture
    __strong UIImage* brushTexture;
}

@end


@implementation JotView

@synthesize delegate;
@synthesize undoLimit;
@synthesize brushTexture;
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
    //
    // this view should accept Jot stylus touch events
    [[JotStylusManager sharedInstance] registerView:self];
    
    // set our default undo limit
    self.undoLimit = kJotDefaultUndoLimit;
    
    // allow more than 1 finger/stylus to draw at a time
    self.multipleTouchEnabled = YES;
    
    // setup our storage for our undo/redo strokes
    currentStrokes = [NSMutableDictionary dictionary];
    stackOfStrokes = [NSMutableArray array];
    stackOfUndoneStrokes = [NSMutableArray array];
    
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
    
    
    [self createDefaultBrushTexture];

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
 * this will set the brush texture for this view
 * by generating a default UIImage. the image is a
 * 20px radius circle with a feathered edge
 */
-(void) createDefaultBrushTexture{
    UIGraphicsBeginImageContext(CGSizeMake(64, 64));
    CGContextRef defBrushTextureContext = UIGraphicsGetCurrentContext();
    UIGraphicsPushContext(defBrushTextureContext);
    
    size_t num_locations = 3;
    CGFloat locations[3] = { 0.0, 0.8, 1.0 };
    CGFloat components[12] = { 1.0,1.0,1.0, 1.0,
        1.0,1.0,1.0, 1.0,
        1.0,1.0,1.0, 0.0 };
    CGColorSpaceRef myColorspace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef myGradient = CGGradientCreateWithColorComponents (myColorspace, components, locations, num_locations);
    
    CGPoint myCentrePoint = CGPointMake(32, 32);
    float myRadius = 20;
    
    CGContextDrawRadialGradient (UIGraphicsGetCurrentContext(), myGradient, myCentrePoint,
                                 0, myCentrePoint, myRadius,
                                 kCGGradientDrawsAfterEndLocation);
    
    UIGraphicsPopContext();
    
    [self setBrushTexture:UIGraphicsGetImageFromCurrentImageContext()];
    
    UIGraphicsEndImageContext();
}



/**
 * this will create the framebuffer and related
 * render and depth buffers that we'll use for
 * drawing
 */
- (BOOL)createFramebuffer{
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
    glOrthof(0, frame.size.width * scale, 0, frame.size.height * scale, -1, 1);
    glViewport(0, 0, frame.size.width * scale, frame.size.height * scale);

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
    backgroundFramebuffer = nil;
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


-(void) exportEverythingOnComplete:(void(^)(UIImage* ink, UIImage* thumb, NSDictionary* state))exportFinishBlock{
    dispatch_semaphore_t sema1 = dispatch_semaphore_create(0);
    dispatch_semaphore_t sema2 = dispatch_semaphore_create(0);
    
    __block UIImage* thumb = nil;
    __block UIImage* ink = nil;
    
    NSMutableDictionary* state = [NSMutableDictionary dictionary];
    [state setObject:[stackOfStrokes copy] forKey:@"stackOfStrokes"];
    [state setObject:[stackOfUndoneStrokes copy] forKey:@"stackOfUndoneStrokes"];
    
    [self exportToImageWithBackgroundColor:nil andBackgroundImage:nil onComplete:^(UIImage* image){
        thumb = image;
        dispatch_semaphore_signal(sema1);
    }];
    
    [backgroundFramebuffer exportTextureOnComplete:^(UIImage* image){
        ink = image;
        dispatch_semaphore_signal(sema2);
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        dispatch_semaphore_wait(sema1, DISPATCH_TIME_FOREVER);
        // i could notify about the thumbnail here
        // which would let the UI swap to the cached thumbnail
        // from the full JotUI if needed... (?)
        // probably an over optimization at this point,
        // but may be useful once multiple JotViews are
        // on screen at a time + being exported simultaneously
        
        dispatch_semaphore_wait(sema2, DISPATCH_TIME_FOREVER);
        
        
        exportFinishBlock(ink, thumb, state);
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
-(void) loadImage:(JotGLTextureBackedFrameBuffer*)textureFramebuffer andState:(NSDictionary*)stateInfo{
    // the FBO for the backing texture
    backgroundFramebuffer = textureFramebuffer;
    // the texture itself
    backgroundTexture = textureFramebuffer.texture;
    
    //
    // reset our undo state
    [stackOfUndoneStrokes removeAllObjects];
    [stackOfStrokes removeAllObjects];
    [currentStrokes removeAllObjects];

    if(stateInfo){
        // load our undo state
        [stackOfUndoneStrokes addObjectsFromArray:[stateInfo objectForKey:@"stackOfUndoneStrokes"]];
        [stackOfStrokes addObjectsFromArray:[stateInfo objectForKey:@"stackOfStrokes"]];
        
        for(JotStroke* stroke in [stackOfStrokes arrayByAddingObjectsFromArray:stackOfUndoneStrokes]){
            stroke.delegate = self;
        }
    }else{
//        NSLog(@"no state info loaded");
    }
    
    //
    // ok, render the new content
    [self renderAllStrokes];
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
-(void) exportToImageWithBackgroundColor:(UIColor*)backgroundColor
                      andBackgroundImage:(UIImage*)backgroundImage
                              onComplete:(void(^)(UIImage*) )exportFinishBlock{
    
    if(!exportFinishBlock) return;
    
    // make sure everything is rendered to the buffer
    [self renderAllStrokes];
    
    GLint backingWidthForRenderBuffer, backingHeightForRenderBuffer;
    //Bind the color renderbuffer used to render the OpenGL ES view
    // If your application only creates a single color renderbuffer which is already bound at this point,
    // this call is redundant, but it is needed if you're dealing with multiple renderbuffers.
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    
    // Get the size of the backing CAEAGLLayer
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidthForRenderBuffer);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeightForRenderBuffer);
    
    // read the image from OpenGL and push it into a data buffer
    NSInteger x = 0, y = 0, width = backingWidthForRenderBuffer, height = backingHeightForRenderBuffer;
    NSInteger dataLength = width * height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(x, y, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    //
    // the rest can be done in Core Graphics in a background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Create a CGImage with the pixel data from OpenGL
        // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
        // otherwise, use kCGImageAlphaPremultipliedLast
        CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
        CGImageRef iref = CGImageCreate(width, height, 8, 32, width * 4, colorspace, kCGBitmapByteOrderDefault |
                                        kCGImageAlphaPremultipliedLast,
                                        ref, NULL, true, kCGRenderingIntentDefault);
        
        //
        // ok, now we have the pixel data from the OpenGL frame buffer.
        // next we need to setup the image context to composite the
        // background color, background image, and opengl image
        
        // OpenGL ES measures data in PIXELS
        // Create a graphics context with the target size measured in POINTS
        CGContextRef bitmapContext = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorspace, kCGBitmapByteOrderDefault |
                                                           kCGImageAlphaPremultipliedLast);
        
        // fill background color, if any
        if(backgroundColor){
            CGContextSetFillColorWithColor(bitmapContext, backgroundColor.CGColor);
            CGContextFillRect(bitmapContext, CGRectMake(0, 0, width, height));
        }
        
        // fill background image, if any
        // and use scale-to-fill, similar to a UIImageView
        if(backgroundImage){
            // find the right location and size to draw the background so that it aspect fills the export image
            CGSize backgroundSize = CGSizeMake(CGImageGetWidth(backgroundImage.CGImage), CGImageGetHeight(backgroundImage.CGImage));
            CGSize finalImageSize = CGSizeMake(width,height);
            CGFloat horizontalRatio = finalImageSize.width / backgroundSize.width;
            CGFloat verticalRatio = finalImageSize.height / backgroundSize.height;
            CGFloat ratio = MAX(horizontalRatio, verticalRatio); //AspectFill
            CGSize aspectFillSize = CGSizeMake(backgroundSize.width * ratio, backgroundSize.height * ratio);
            
            //Draw our image centered vertically and horizontally in our context.
            CGContextDrawImage(bitmapContext,
                               CGRectMake((finalImageSize.width-aspectFillSize.width)/2,
                                          (finalImageSize.height-aspectFillSize.height)/2,
                                          aspectFillSize.width,
                                          aspectFillSize.height),
                               backgroundImage.CGImage);
        }
        
        // flip vertical for our drawn content, since OpenGL is opposite core graphics
        CGContextTranslateCTM(bitmapContext, 0, height);
        CGContextScaleCTM(bitmapContext, 1.0, -1.0);
        
        //
        // ok, now render our actual content
        CGContextDrawImage(bitmapContext, CGRectMake(0.0, 0.0, width, height), iref);
        
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
-(void) renderAllStrokes{
    //
    // hang onto the current texture
    // so we can reset it after we draw
    // the strokes
    UIImage* keepThisTexture = brushTexture;
    
    // set our current OpenGL context
    [EAGLContext setCurrentContext:context];
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);

	//
    // step 1:
    // Clear the buffer
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
    
    
    //
    // step 2:
    // load a texture and draw it into a quad
    // that fills the screen
    [backgroundTexture draw];
    
    //
    // ok, we're done rendering the background texture to the quad
    //
    
    
    //
    // step 3:
    // draw all the strokes that we have in our undo-able stack
    [self prepOpenGLStateForFBO:viewFramebuffer];
    // reset the texture so that we load the brush texture next
    brushTexture = nil;
    // now draw the strokes
    for(JotStroke* stroke in [stackOfStrokes arrayByAddingObjectsFromArray:[currentStrokes allValues]]){
        // make sure our texture is the correct one for this stroke
        if(stroke.texture != brushTexture){
            [self setBrushTexture:stroke.texture];
        }
        // setup our blend mode properly for color vs eraser
        if(stroke.segments){
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
    
    // step 4:
    // ok, show it!
    [self presentRenderBuffer];
    
    // now that we're done rendering strokes, reset the texture
    // to the current brush
    [self setBrushTexture:keepThisTexture];
}


/**
 * this is a simple method to display our renderbuffer
 */
-(void) presentRenderBuffer{
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
    struct Vertex* vertexBuffer = [element generatedVertexArrayWithPreviousElement:previousElement forScale:scale];
    
    glLineWidth(2);
    
    // if the element has any data, then draw it
    if(vertexBuffer){
        glVertexPointer(2, GL_FLOAT, sizeof(struct Vertex), &vertexBuffer[0].Position[0]);
        glColorPointer(4, GL_FLOAT, sizeof(struct Vertex), &vertexBuffer[0].Color[0]);
        glTexCoordPointer(2, GL_FLOAT, sizeof(struct Vertex), &vertexBuffer[0].Texture[0]);
        glDrawArrays(GL_TRIANGLES, 0, [element numberOfSteps] * [element numberOfVerticesPerStep]);
    }
    
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
    if([stackOfStrokes count] > self.undoLimit){
        UIImage* keepThisTexture = brushTexture;
        while([stackOfStrokes count] > self.undoLimit){
            // get the stroke that we need to make permanent
            JotStroke* strokeToWriteToTexture = [stackOfStrokes objectAtIndex:0];
            [stackOfStrokes removeObject:strokeToWriteToTexture];
            
            // render it to the backing texture
            [self prepOpenGLStateForFBO:backgroundFramebuffer.framebufferID];
            // reset the texture so that we load the brush texture next
            brushTexture = nil;
            // now draw the strokes
            
            // make sure our texture is the correct one for this stroke
            if(strokeToWriteToTexture.texture != brushTexture){
                [self setBrushTexture:strokeToWriteToTexture.texture];
            }
            // setup our blend mode properly for color vs eraser
            if(strokeToWriteToTexture.segments){
                AbstractBezierPathElement* firstElement = [strokeToWriteToTexture.segments objectAtIndex:0];
                [self prepOpenGLBlendModeForColor:firstElement.color];
            }
            
            // draw each stroke element
            AbstractBezierPathElement* prevElement = nil;
            for(AbstractBezierPathElement* element in strokeToWriteToTexture.segments){
                [self renderElement:element fromPreviousElement:prevElement includeOpenGLPrepForFBO:nil];
                prevElement = element;
            }
            
            [self unprepOpenGLState];
        }
        [self setBrushTexture:keepThisTexture];
    }
}


#pragma mark - JotStrokeDelegate

-(void) jotStrokeWasCancelled:(JotStroke*)stroke{
    for(id key in [currentStrokes allKeys]){
        JotStroke* aStroke = [currentStrokes objectForKey:key];
        if(aStroke == stroke){
            [currentStrokes removeObjectForKey:key];
            [self renderAllStrokes];
            return;
        }
    }
}


#pragma mark - JotPalmRejectionDelegate

/**
 * Handles the start of a touch
 */
-(void)jotStylusTouchBegan:(NSSet *) touches{
    for(JotTouch* jotTouch in touches){
        if([self.delegate willBeginStrokeWithTouch:jotTouch]){
            JotStroke* newStroke = [[JotStrokeManager sharedInstace] makeStrokeForTouchHash:jotTouch.touch andTexture:brushTexture];
            newStroke.delegate = self;
            [currentStrokes setObject:newStroke forKey:@(jotTouch.touch.hash)];
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
            
            [self.delegate didEndStrokeWithTouch:jotTouch];
            
            // this stroke is now finished, so add it to our completed strokes stack
            // and remove it from the current strokes, and reset our undo state if any
            [stackOfStrokes addObject:currentStroke];
            [currentStrokes removeObjectForKey:@(jotTouch.touch.hash)];
            [stackOfUndoneStrokes removeAllObjects];
            [self validateUndoState];
            [[JotStrokeManager sharedInstace] removeStrokeForTouch:jotTouch.touch];
        }
    }
}

/**
 * Handles the end of a touch event.
 */
-(void)jotStylusTouchCancelled:(NSSet *) touches{
    for(JotTouch* jotTouch in touches){
        // If appropriate, add code necessary to save the state of the application.
        // This application is not saving state.
        if([[JotStrokeManager sharedInstace] cancelStrokeForTouch:jotTouch.touch]){
            [self.delegate didCancelStrokeWithTouch:jotTouch];
            [currentStrokes removeObjectForKey:@(jotTouch.touch.hash)];
        }
    }
    // we need to erase the current stroke from the screen, so
    // clear the canvas and rerender all valid strokes
    [self renderAllStrokes];
}


-(void)jotSuggestsToDisableGestures{
    if([self.delegate respondsToSelector:@selector(jotSuggestsToDisableGestures)]){
        [self.delegate jotSuggestsToDisableGestures];
    }
    
}
-(void)jotSuggestsToEnableGestures{
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
                [currentStrokes setObject:newStroke forKey:@(jotTouch.touch.hash)];
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
                [stackOfStrokes addObject:currentStroke];
                [currentStrokes removeObjectForKey:@(jotTouch.touch.hash)];
                [stackOfUndoneStrokes removeAllObjects];
                [self validateUndoState];
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
                [currentStrokes removeObjectForKey:@(jotTouch.touch.hash)];
            }
        }
        // we need to erase the current stroke from the screen, so
        // clear the canvas and rerender all valid strokes
        [self renderAllStrokes];
    }
}



#pragma mark - Public Interface

/**
 * setup the texture to use for the next brush stroke
 */
-(void) setBrushTexture:(UIImage*)brushImage{
    // save our current texture.
    brushTexture = brushImage;
    
    // first, delete the old texture if needed
	if (glBrushTextureID){
		glDeleteTextures(1, &glBrushTextureID);
		glBrushTextureID = 0;
	}
    
    // fetch the cgimage for us to draw into a texture
    CGImageRef brushCGImage = brushImage.CGImage;
    
    // Make sure the image exists
    if(brushCGImage) {
        // Get the width and height of the image
        size_t width = CGImageGetWidth(brushCGImage);
        size_t height = CGImageGetHeight(brushCGImage);
        
        // Texture dimensions must be a power of 2. If you write an application that allows users to supply an image,
        // you'll want to add code that checks the dimensions and takes appropriate action if they are not a power of 2.
        
        // Allocate  memory needed for the bitmap context
        GLubyte* brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
        // Use  the bitmatp creation function provided by the Core Graphics framework.
        CGContextRef brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushCGImage), kCGImageAlphaPremultipliedLast);
        // After you create the context, you can draw the  image to the context.
        CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushCGImage);
        // You don't need the context at this point, so you need to release it to avoid memory leaks.
        CGContextRelease(brushContext);
        // Use OpenGL ES to generate a name for the texture.
        glGenTextures(1, &glBrushTextureID);
        // Bind the texture name.
        glBindTexture(GL_TEXTURE_2D, glBrushTextureID);
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // Specify a 2D texture image, providing the a pointer to the image data in memory
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
        // Release  the image data; it's no longer needed
        free(brushData);
    }
}


/**
 * this will move one of the completed strokes to the undo
 * stack, and then rerender all other completed strokes
 */
-(IBAction) undo{
    if([stackOfStrokes count]){
        [stackOfUndoneStrokes addObject:[stackOfStrokes lastObject]];
        [stackOfStrokes removeLastObject];
        [self renderAllStrokes];
    }
}

/**
 * if we have undone strokes, then move the most recent
 * undo back to the completed strokes list, then rerender
 */
-(IBAction) redo{
    if([stackOfUndoneStrokes count]){
        [stackOfStrokes addObject:[stackOfUndoneStrokes lastObject]];
        [stackOfUndoneStrokes removeLastObject];
        [self renderAllStrokes];
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
    [backgroundFramebuffer clear];

	// Display the buffer
    [self presentRenderBuffer];
    
    // reset undo state
    [stackOfUndoneStrokes removeAllObjects];
    [stackOfStrokes removeAllObjects];
    [currentStrokes removeAllObjects];
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
    for(JotStroke* stroke in stackOfStrokes){
        hashVal += [stroke hash];
    }
    for(JotStroke* stroke in currentStrokes){
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

	if (glBrushTextureID){
		glDeleteTextures(1, &glBrushTextureID);
		glBrushTextureID = 0;
	}
	if([EAGLContext currentContext] == context){
		[EAGLContext setCurrentContext:nil];
	}
    
    if(backgroundFramebuffer){
        glDeleteFramebuffersOES(1, &backgroundFramebuffer);
        backgroundFramebuffer = 0;
    }
}


@end
