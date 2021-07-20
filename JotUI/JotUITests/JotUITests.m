//
//  JotUITests.m
//  JotUITests
//
//  Created by Adam Wulf on 11/1/20.
//  Copyright © 2020 Milestone Made. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <JotUI/JotUI.h>
#import <JotUI/SegmentSmoother.h>

#define kPrecision 6

@interface JotUITests : XCTestCase

@end

@implementation JotUITests

- (CGFloat)nearNum:(CGFloat)num digits:(int)digits {
    return round(num * pow(10, digits)) / pow(10, digits);
}

- (void)assertNear:(CGFloat)num1 and:(CGFloat)num2 {
    CGFloat rnd1 = [self nearNum:num1 digits:kPrecision];
    CGFloat rnd2 = [self nearNum:num2 digits:kPrecision];

    if (rnd1 != rnd2) {
        XCTFail("%f does not equal %f within %d precision", num1, num2, kPrecision);
    }
}

- (void)testThreePoints {
    SegmentSmoother *smoother = [[SegmentSmoother alloc] init];

    [smoother addPoint:CGPointMake(100, 100) andSmoothness:0.7];
    [smoother addPoint:CGPointMake(200, 150) andSmoothness:0.7];
    AbstractBezierPathElement *ele = [smoother addPoint:CGPointMake(300, 150) andSmoothness:0.7];

    XCTAssertTrue([ele isKindOfClass:[CurveToPathElement class]]);

    CurveToPathElement *curve = (CurveToPathElement*)ele;

    XCTAssertEqual([curve startPoint].x, 100);
    XCTAssertEqual([curve startPoint].y, 100);
    XCTAssertEqual([curve endPoint].x, 200);
    XCTAssertEqual([curve endPoint].y, 150);
    XCTAssertEqual([curve ctrl1].x, 135);
    XCTAssertEqual([curve ctrl1].y, 117.5);
    [self assertNear:[curve ctrl2].x and:163.049514771];
    [self assertNear:[curve ctrl2].y and:140.762374878];
}

- (void)testFourPoints {
    SegmentSmoother *smoother = [[SegmentSmoother alloc] init];

    [smoother addPoint:CGPointMake(100, 100) andSmoothness:0.7];
    [smoother addPoint:CGPointMake(200, 150) andSmoothness:0.7];
    [smoother addPoint:CGPointMake(300, 150) andSmoothness:0.7];
    AbstractBezierPathElement *ele = [smoother addPoint:CGPointMake(400, 100) andSmoothness:0.7];

    XCTAssertTrue([ele isKindOfClass:[CurveToPathElement class]]);

    CurveToPathElement *curve = (CurveToPathElement*)ele;

    XCTAssertEqual([curve startPoint].x, 200);
    XCTAssertEqual([curve startPoint].y, 150);
    XCTAssertEqual([curve endPoint].x, 300);
    XCTAssertEqual([curve endPoint].y, 150);
    [self assertNear:[curve ctrl1].x and:233.04951477050781];
    [self assertNear:[curve ctrl1].y and:158.26237487792969];
    [self assertNear:[curve ctrl2].x and:266.95046997070313];
    [self assertNear:[curve ctrl2].y and:158.26237487792969];
}

- (void)testFivePoints {
    SegmentSmoother *smoother = [[SegmentSmoother alloc] init];

    [smoother addPoint:CGPointMake(100, 100) andSmoothness:0.7];
    [smoother addPoint:CGPointMake(200, 150) andSmoothness:0.7];
    [smoother addPoint:CGPointMake(300, 150) andSmoothness:0.7];
    [smoother addPoint:CGPointMake(400, 100) andSmoothness:0.7];
    AbstractBezierPathElement *ele = [smoother addPoint:CGPointMake(500, 120) andSmoothness:0.7];

    XCTAssertTrue([ele isKindOfClass:[CurveToPathElement class]]);

    CurveToPathElement *curve = (CurveToPathElement*)ele;

    XCTAssertEqual([curve startPoint].x, 300);
    XCTAssertEqual([curve startPoint].y, 150);
    XCTAssertEqual([curve endPoint].x, 400);
    XCTAssertEqual([curve endPoint].y, 100);
    [self assertNear:[curve ctrl1].x and:336.95046997070313];
    [self assertNear:[curve ctrl1].y and:140.76237487792969];
    [self assertNear:[curve ctrl2].x and:363.39181518554688];
    [self assertNear:[curve ctrl2].y and:105.49122619628906];
}

- (void)testFivePointsWithForcedEnd {
    SegmentSmoother *smoother = [[SegmentSmoother alloc] init];

    [smoother addPoint:CGPointMake(100, 100) andSmoothness:0.7];
    [smoother addPoint:CGPointMake(200, 150) andSmoothness:0.7];
    [smoother addPoint:CGPointMake(300, 150) andSmoothness:0.7];
    [smoother addPoint:CGPointMake(400, 100) andSmoothness:0.7];
    [smoother addPoint:CGPointMake(500, 120) andSmoothness:0.7];
    AbstractBezierPathElement *ele = [smoother addPoint:CGPointMake(500, 120) andSmoothness:0.7];

    XCTAssertTrue([ele isKindOfClass:[CurveToPathElement class]]);

    CurveToPathElement *curve = (CurveToPathElement*)ele;

    XCTAssertEqual([curve startPoint].x, 400);
    XCTAssertEqual([curve startPoint].y, 100);
    XCTAssertEqual([curve endPoint].x, 500);
    XCTAssertEqual([curve endPoint].y, 120);
    [self assertNear:[curve ctrl1].x and:433.39181518554688];
    [self assertNear:[curve ctrl1].y and:94.991226196289063];
    [self assertNear:[curve ctrl2].x and:465];
    [self assertNear:[curve ctrl2].y and:113];
}

@end
