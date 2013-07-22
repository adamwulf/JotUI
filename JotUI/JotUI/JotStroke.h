//
//  JotStroke.h
//  JotTouchExample
//
//  Created by Adam Wulf on 1/9/13.
//  Copyright (c) 2013 Adonit, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JotStrokeDelegate.h"
#import "JotBrushTexture.h"
#import "PlistSaving.h"

@class SegmentSmoother, AbstractBezierPathElement;

/**
 * a simple class to help us manage a single
 * smooth curved line. each segment will interpolate
 * between points into a nice single curve, and also
 * interpolate width and color including alpha
 */
@interface JotStroke : NSObject<PlistSaving>

@property (nonatomic, readonly) SegmentSmoother* segmentSmoother;
@property (nonatomic, readonly) NSArray* segments;
@property (nonatomic, readonly) JotBrushTexture* texture;
@property (nonatomic, weak) NSObject<JotStrokeDelegate>* delegate;
@property (nonatomic, readonly) NSInteger totalNumberOfBytes;

/**
 * create an empty stroke with the input texture
 */
-(id) initWithTexture:(JotBrushTexture*)_texture;

-(CGRect) bounds;

/**
 * will add the input bezier element to the end of the stroke
 */
-(void) addElement:(AbstractBezierPathElement*)element;

/**
 * remove a segment from the stroke
 */
-(void) removeElementAtIndex:(NSInteger)index;

/**
 * cancel the stroke and notify the delegate
 */
-(void) cancel;

-(NSString*) uuid;

@end
