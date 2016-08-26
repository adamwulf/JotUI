//
//  SegmentSmoother.h
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "PlistSaving.h"

@class AbstractBezierPathElement;


@interface SegmentSmoother : NSObject <PlistSaving> {
    CGPoint point0;
    CGPoint point1;
    CGPoint point2;
    CGPoint point3;
}

@property(nonatomic, readonly) CGPoint point0;
@property(nonatomic, readonly) CGPoint point1;
@property(nonatomic, readonly) CGPoint point2;
@property(nonatomic, readonly) CGPoint point3;


/**
 * This method will add the point and try to interpolate a
 * curve/line/moveto segment from this new point and the points
 * that have come before.
 *
 * The first two points will generate the first moveto segment,
 * and subsequent points after that will generate curve
 * segments
 */
- (AbstractBezierPathElement*)addPoint:(CGPoint)inPoint andSmoothness:(CGFloat)smoothFactor;

- (void)copyStateFrom:(SegmentSmoother*)otherSmoother;

- (void)scaleForWidth:(CGFloat)widthRatio andHeight:(CGFloat)heightRatio;

@end
