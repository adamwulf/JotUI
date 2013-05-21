//
//  CurveToPathElement.h
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "LineToPathElement.h"

@interface CurveToPathElement : LineToPathElement{
    CGPoint curveTo;
    CGPoint ctrl1;
    CGPoint ctrl2;
    
    CGFloat length;
    
    NSMutableArray* cachedPointSteps;
    NSMutableArray* cachedColorSteps;
}

@property (nonatomic, readonly) CGPoint curveTo;
@property (nonatomic, readonly) CGPoint ctrl1;
@property (nonatomic, readonly) CGPoint ctrl2;


+(id) elementWithStart:(CGPoint)start
            andCurveTo:(CGPoint)curveTo
           andControl1:(CGPoint)ctrl1
           andControl2:(CGPoint)ctrl2;


@end
