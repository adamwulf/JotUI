//
//  SegmentSmoother.h
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AbstractBezierPathElement;

@interface SegmentSmoother : NSObject{
    CGPoint point0;
    CGPoint point1;
    CGPoint point2;
    CGPoint point3;
}

/**
 * This method will add the point and try to interpolate a
 * curve/line/moveto segment from this new point and the points
 * that have come before.
 *
 * The first two points will generate the first moveto segment,
 * and subsequent points after that will generate curve
 * segments
 */
-(AbstractBezierPathElement*) addPoint:(CGPoint)inPoint andSmoothness:(CGFloat)smoothFactor;

@end
