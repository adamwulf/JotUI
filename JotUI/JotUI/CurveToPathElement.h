//
//  CurveToPathElement.h
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "AbstractBezierPathElement.h"

extern const CGPoint JotCGNotFoundPoint;

@interface CurveToPathElement : AbstractBezierPathElement{
    CGPoint curveTo;
    CGPoint ctrl1;
    CGPoint ctrl2;
    
    CGFloat length;


    CGRect boundsCache;
    // store the number of bytes of data that we've generated
    NSInteger numberOfBytesOfVertexData;
    CGFloat subBezierlengthCache[1000];
    // a boolean for if color information is encoded in the VBO
    BOOL vertexBufferShouldContainColor;
}

@property (nonatomic, readonly) CGPoint curveTo;
@property (nonatomic, readonly) CGPoint ctrl1;
@property (nonatomic, readonly) CGPoint ctrl2;


+(id) elementWithStart:(CGPoint)start
            andCurveTo:(CGPoint)curveTo
           andControl1:(CGPoint)ctrl1
           andControl2:(CGPoint)ctrl2;

+(id) elementWithStart:(CGPoint)start andLineTo:(CGPoint)point;


// protected

-(void) validateVertexData:(struct ColorfulVertex)vertex;

extern CGFloat subdivideBezierAtLength2 (const CGPoint bez[4],
                                        CGPoint bez1[4],
                                        CGPoint bez2[4],
                                        CGFloat length,
                                        CGFloat acceptableError,
                                        CGFloat* subBezierlengthCache);

@end
