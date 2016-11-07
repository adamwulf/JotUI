//
//  SegmentSmoother.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import "SegmentSmoother.h"
#import "AbstractBezierPathElement.h"
#import "CurveToPathElement.h"
#import "MoveToPathElement.h"


@implementation SegmentSmoother

@synthesize point0;
@synthesize point1;
@synthesize point2;
@synthesize point3;

- (id)init {
    if (self = [super init]) {
        point0 = CGPointMake(-CGFLOAT_MAX, -CGFLOAT_MAX);
        point1 = CGPointMake(-CGFLOAT_MAX, -CGFLOAT_MAX); // previous previous point
        point2 = CGPointMake(-CGFLOAT_MAX, -CGFLOAT_MAX); // previous touch point
        point3 = CGPointMake(-CGFLOAT_MAX, -CGFLOAT_MAX);
    }
    return self;
}

/**
 * This method will add the point and try to interpolate a
 * curve/line/moveto segment from this new point and the points
 * that have come before.
 *
 * The first two points will generate the first moveto segment,
 * and subsequent points after that will generate curve
 * segments
 *
 * code modified from: http://www.effectiveui.com/blog/2011/12/02/how-to-build-a-simple-painting-app-for-ios/
 */
- (AbstractBezierPathElement*)addPoint:(CGPoint)inPoint andSmoothness:(CGFloat)smoothFactor {
    // update the points
    point0 = point1;
    point1 = point2;
    point2 = point3;
    point3 = inPoint;

    // determine if we need a new segment
    if (point1.x > -CGFLOAT_MAX) {
        double x0 = (point0.x > -CGFLOAT_MAX) ? point0.x : point1.x; //after 4 touches we should have a back anchor point, if not, use the current anchor point
        double y0 = (point0.y > -CGFLOAT_MAX) ? point0.y : point1.y; //after 4 touches we should have a back anchor point, if not, use the current anchor point
        double x1 = point1.x;
        double y1 = point1.y;
        double x2 = point2.x;
        double y2 = point2.y;
        double x3 = point3.x;
        double y3 = point3.y;

        // Assume we need to calculate the control
        // points between (x1,y1) and (x2,y2).
        // Then x0,y0 - the previous vertex,
        //      x3,y3 - the next one.

        double xc1 = (x0 + x1) / 2.0;
        double yc1 = (y0 + y1) / 2.0;
        double xc2 = (x1 + x2) / 2.0;
        double yc2 = (y1 + y2) / 2.0;
        double xc3 = (x2 + x3) / 2.0;
        double yc3 = (y2 + y3) / 2.0;

        double len1 = sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
        double len2 = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
        double len3 = sqrt((x3 - x2) * (x3 - x2) + (y3 - y2) * (y3 - y2));

        double k1 = len1 / (len1 + len2);
        double k2 = len2 / (len2 + len3);

        double xm1 = xc1 + (xc2 - xc1) * k1;
        double ym1 = yc1 + (yc2 - yc1) * k1;

        double xm2 = xc2 + (xc3 - xc2) * k2;
        double ym2 = yc2 + (yc3 - yc2) * k2;
        double smooth_value = smoothFactor;

        // Resulting control points. Here smooth_value is mentioned
        // above coefficient K whose value should be in range [0...1].
        float ctrl1_x = xm1 + (xc2 - xm1) * smooth_value + x1 - xm1;
        float ctrl1_y = ym1 + (yc2 - ym1) * smooth_value + y1 - ym1;

        float ctrl2_x = xm2 + (xc2 - xm2) * smooth_value + x2 - xm2;
        float ctrl2_y = ym2 + (yc2 - ym2) * smooth_value + y2 - ym2;

        if (isnan(ctrl1_x) || isnan(ctrl1_y)) {
            ctrl1_x = point1.x;
            ctrl1_y = point1.y;
        }

        if (isnan(ctrl2_x) || isnan(ctrl2_y)) {
            ctrl2_x = point2.x;
            ctrl2_y = point2.y;
        }

        return [CurveToPathElement elementWithStart:point1
                                         andCurveTo:point2
                                        andControl1:CGPointMake(ctrl1_x, ctrl1_y)
                                        andControl2:CGPointMake(ctrl2_x, ctrl2_y)];
    } else if (point2.x == -CGFLOAT_MAX) {
        return [MoveToPathElement elementWithMoveTo:point3];
    }

    return nil;
}


- (void)copyStateFrom:(SegmentSmoother*)otherSmoother {
    point0 = otherSmoother.point0;
    point1 = otherSmoother.point1;
    point2 = otherSmoother.point2;
    point3 = otherSmoother.point3;
}


#pragma mark - PlistSaving

- (NSDictionary*)asDictionary {
    return [NSDictionary dictionaryWithObjectsAndKeys:NSStringFromCGPoint(point0), @"point0",
                                                      NSStringFromCGPoint(point1), @"point1",
                                                      NSStringFromCGPoint(point2), @"point2",
                                                      NSStringFromCGPoint(point3), @"point3", nil];
}

- (id)initFromDictionary:(NSDictionary*)dictionary {
    if (self = [super init]) {
        point0 = CGPointFromString([dictionary objectForKey:@"point0"]);
        point1 = CGPointFromString([dictionary objectForKey:@"point1"]);
        point2 = CGPointFromString([dictionary objectForKey:@"point2"]);
        point3 = CGPointFromString([dictionary objectForKey:@"point3"]);
    }
    return self;
}

#pragma mark - Scale

- (void)scaleForWidth:(CGFloat)widthRatio andHeight:(CGFloat)heightRatio {
    point0.x = point0.x * widthRatio;
    point0.y = point0.y * heightRatio;
    point1.x = point1.x * widthRatio;
    point1.y = point1.y * heightRatio;
    point2.x = point2.x * widthRatio;
    point2.y = point2.y * heightRatio;
    point3.x = point3.x * widthRatio;
    point3.y = point3.y * heightRatio;
}

@end
