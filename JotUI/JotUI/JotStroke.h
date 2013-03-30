//
//  JotStroke.h
//  JotTouchExample
//
//  Created by Adam Wulf on 1/9/13.
//  Copyright (c) 2013 Adonit, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SegmentSmoother.h"

/**
 * a simple class to help us manage a single
 * smooth curved line. each segment will interpolate
 * between points into a nice single curve, and also
 * interpolate width and color including alpha
 */
@interface JotStroke : NSObject{
    // this will interpolate between points into curved segments
    SegmentSmoother* segmentSmoother;
    // this will store all the segments in drawn order
    NSMutableArray* segments;
    // this is the texture to use when drawing the stroke
    UIImage* texture;
}

@property (nonatomic, readonly) SegmentSmoother* segmentSmoother;
@property (nonatomic, readonly) NSMutableArray* segments;
@property (nonatomic, readonly) UIImage* texture;

/**
 * create an empty stroke with the input texture
 */
-(id) initWithTexture:(UIImage*)_texture;

/**
 * returns YES if the point modified the stroke by adding a new segment,
 * or NO if the segment is unmodified because there are still too few
 * points to interpolate
 *
 * @param point the point to add to the stroke
 * @param width the width of stroke at the input point
 * @param color the color of the stroke at the input point
 * @param smoothFactor the smoothness between the previous point and the input point.
 *        0 is straight, 1 is curvy, > 1 and < 0 is loopy or bouncy
 */
-(BOOL) addPoint:(CGPoint)point withWidth:(CGFloat)width andColor:(UIColor*)color andSmoothness:(CGFloat)smoothFactor;



@end
