//
//  JotStroke.h
//  JotTouchExample
//
//  Created by Adam Wulf on 1/9/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JotStrokeDelegate.h"
#import "JotBrushTexture.h"
#import "PlistSaving.h"
#import "JotBufferManager.h"

@class SegmentSmoother, AbstractBezierPathElement;

/**
 * a simple class to help us manage a single
 * smooth curved line. each segment will interpolate
 * between points into a nice single curve, and also
 * interpolate width and color including alpha
 */
@interface JotStroke : NSObject <PlistSaving> {
    // this will store all the segments in drawn order
    NSMutableArray* segments;
    // cache the hash, since it's expenseive to calculate
    NSUInteger hashCache;
}

@property(nonatomic, readonly) SegmentSmoother* segmentSmoother;
@property(nonatomic, readonly) NSArray* segments;
@property(nonatomic, readonly) JotBrushTexture* texture;
@property(nonatomic, weak) NSObject<JotStrokeDelegate>* delegate;
@property(nonatomic, readonly) NSInteger totalNumberOfBytes;
@property(nonatomic, strong) JotBufferManager* bufferManager;
@property(nonatomic, readonly) int fullByteSize;

/**
 * create an empty stroke with the input texture
 */
- (id)initWithTexture:(JotBrushTexture*)_texture andBufferManager:(JotBufferManager*)bufferManager;

- (CGRect)bounds;

/**
 * will add the input bezier element to the end of the stroke
 */
- (void)addElement:(AbstractBezierPathElement*)element;

/**
 * remove a segment from the stroke
 */
- (void)removeElementAtIndex:(NSInteger)index;

/**
 * cancel the stroke and notify the delegate
 */
- (void)cancel;

/**
 * removes all segments, use with caution
 */
- (void)empty;

- (NSString*)uuid;

- (void)lock;
- (void)unlock;

- (void)scaleSegmentsForWidth:(CGFloat)widthRatio andHeight:(CGFloat)heightRatio;

@end
