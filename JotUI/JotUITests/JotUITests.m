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

- (CGFloat) nearNum:(CGFloat)num digits:(int)digits {
    return round(num * pow(10, digits)) / pow(10, digits);
}

- (void)testExample {
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
    XCTAssertEqual([self nearNum:[curve ctrl2].x digits:kPrecision], [self nearNum:163.049514771 digits:kPrecision]);
    XCTAssertEqual([self nearNum:[curve ctrl2].y digits:kPrecision], [self nearNum:140.762374878 digits:kPrecision]);
}

@end
