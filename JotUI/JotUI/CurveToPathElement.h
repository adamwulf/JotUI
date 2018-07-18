//
//  CurveToPathElement.h
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "AbstractBezierPathElement.h"


@interface CurveToPathElement : AbstractBezierPathElement {
    CGPoint _curveTo;
    CGPoint _ctrl1;
    CGPoint _ctrl2;

    CGFloat _length;
}

@property(nonatomic, readonly) CGPoint curveTo;
@property(nonatomic, readonly) CGPoint ctrl1;
@property(nonatomic, readonly) CGPoint ctrl2;


+ (id)elementWithStart:(CGPoint)start
            andCurveTo:(CGPoint)curveTo
           andControl1:(CGPoint)ctrl1
           andControl2:(CGPoint)ctrl2;

+ (id)elementWithStart:(CGPoint)start andLineTo:(CGPoint)point;

@end
