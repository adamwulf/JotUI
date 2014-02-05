//
//  FilledPathElement.m
//  JotUI
//
//  Created by Adam Wulf on 2/5/14.
//  Copyright (c) 2014 Adonit. All rights reserved.
//

#import "FilledPathElement.h"
#import "AbstractBezierPathElement-Protected.h"
#import <MessageUI/MFMailComposeViewController.h>

@implementation FilledPathElement{
    // cache the hash, since it's expenseive to calculate
    NSUInteger hashCache;
    // bezier path
    UIBezierPath* path;
    // create texture
    JotGLTexture* texture;
}

-(UIColor*) color{
    return [UIColor blackColor];
}


-(id) initWithPath:(UIBezierPath*) _path{
    if(self = [super initWithStart:CGPointZero]){
        NSUInteger prime = 31;
        hashCache = 1;
        hashCache = prime * hashCache + [path hash];
        path = [_path copy];
        [path applyTransform:CGAffineTransformMakeTranslation(-path.bounds.origin.x, -path.bounds.origin.y)];
        
        
        CGRect textureBounds = CGRectMake(0, 0, ceilf(path.bounds.size.width), ceilf(path.bounds.size.height));
        
        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
        CGContextRef bitmapContext = CGBitmapContextCreate(NULL, textureBounds.size.width, textureBounds.size.height, 8, textureBounds.size.width * 4, colorspace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
        if(!bitmapContext){
            @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
        }
        UIGraphicsPushContext(bitmapContext);

        CGContextClearRect(bitmapContext, CGRectMake(0, 0, textureBounds.size.width, textureBounds.size.height));
        
        // flip vertical for our drawn content, since OpenGL is opposite core graphics
        CGContextTranslateCTM(bitmapContext, 0, path.bounds.size.height);
        CGContextScaleCTM(bitmapContext, 1.0, -1.0);
        
        //
        // ok, now render our actual content
        CGContextClearRect(bitmapContext, CGRectMake(0.0, 0.0, textureBounds.size.width, textureBounds.size.height));
        path.lineWidth = 3;
        [[UIColor redColor] setStroke];
        [path stroke];
        
        // Retrieve the UIImage from the current context
        CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
        if(!cgImage){
            @throw [NSException exceptionWithName:@"CGContext Exception" reason:@"can't create new context" userInfo:nil];
        }
        
        UIImage* image = [UIImage imageWithCGImage:cgImage scale:1.0 orientation:UIImageOrientationUp];
        
        // Clean up
        CFRelease(colorspace);
        UIGraphicsPopContext();
        CGContextRelease(bitmapContext);
        
        // ok, we're done exporting and cleaning up
        // so pass the newly generated image to the completion block
        texture = [[JotGLTexture alloc] initForImage:image withSize:image.size];
        CGImageRelease(cgImage);
    }
    return self;
}



+(id) elementWithPath:(UIBezierPath*)path{
    return [[FilledPathElement alloc]  initWithPath:path];;
}

/**
 * the length along the curve of this element.
 * since it's a curve, this will be longer than
 * the straight distance between start/end points
 */
-(CGFloat) lengthOfElement{
    return 0;
}

-(CGRect) bounds{
    return [path bounds];
}


-(NSInteger) numberOfBytesGivenPreviousElement:(AbstractBezierPathElement*)previousElement{
    // find out how many steps we can put inside this segment length
    return 0;
}

/**
 * generate a vertex buffer array for all of the points
 * along this curve for the input scale.
 *
 * this method will cache the array for a single scale. if
 * a new scale is sent in later, then the cache will be rebuilt
 * for the new scale.
 */
-(struct ColorfulVertex*) generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale{
    return nil;
}


-(void) loadDataIntoVBOIfNeeded{
    // noop
}


-(void) draw{
    [self bind];
    [texture drawInContext:(JotGLContext*)[JotGLContext currentContext]];
    [self unbind];
}


/**
 * this method has become quite a bit more complex
 * than it was originally.
 *
 * when this method is called from a background thread,
 * it will generate and bind the VBO only. it won't create
 * a VAO
 *
 * when this method is called on the main thread, it will
 * create the VAO, and will also create the VBO to go with
 * it if needed. otherwise it'll bind the VBO from the
 * background thread into the VAO
 *
 * the [unbind] method will unbind either the VAO or VBO
 * depending on which was created/bound in this method+thread
 */
-(BOOL) bind{
    [texture bind];
    return YES;
}

-(void) unbind{
    // noop
}


-(void) dealloc{
    texture = nil;
}

/**
 * helpful description when debugging
 */
-(NSString*)description{
    return @"[FilledPathSegment]";
}




#pragma mark - PlistSaving

-(NSDictionary*) asDictionary{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:[super asDictionary]];
    return [NSDictionary dictionaryWithDictionary:dict];
}

-(id) initFromDictionary:(NSDictionary*)dictionary{
    self = [super initFromDictionary:dictionary];
    if (self) {
        // load from dictionary
    }
    return self;
}

/**
 * if we ever change how we render segments, then the data that's stored in our
 * dataVertexBuffer will contain "bad" data, since it would have been generated
 * for an older/different render method.
 *
 * we need to validate that we have the exact number of bytes of data to render
 * that we think we do
 */
-(void) validateDataGivenPreviousElement:(AbstractBezierPathElement*)previousElement{
    // noop
}

-(UIBezierPath*) bezierPathSegment{
    return path;
}


#pragma mark - hashing and equality

-(NSUInteger) hash{
    return hashCache;
}

-(BOOL) isEqual:(id)object{
    return self == object || [self hash] == [object hash];
}

@end
