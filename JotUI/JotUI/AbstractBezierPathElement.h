//
//  AbstractSegment.h
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PlistSaving.h"
#import "JotBufferManager.h"

#ifndef AbstractBezierPathElement_H
#define AbstractBezierPathElement_H

struct ColorfulVertex {
    GLfloat Position[2]; // x,y position   // 8
    GLfloat Color[4]; // rgba color     // 16
    GLfloat Size; // pixel size     // 4
};

struct ColorlessVertex {
    GLfloat Position[2]; // x,y position   // 8
    GLfloat Size; // pixel size     // 4
};

#endif

/**
 * This represents the number of points to move
 * along the curve before drawing another point
 * on the line.
 *
 * larger values mean that points will be further
 * apart, smaller values means closer together
 *
 * small values will also give a smoother line, but will
 * cost more in CPU
 */
#define kBrushStepSize 1


@interface AbstractBezierPathElement : NSObject <PlistSaving> {
    CGPoint _startPoint;
    CGFloat _width;
    UIColor* _color;

    NSData* _dataVertexBuffer;
    CGFloat _scaleOfVertexBuffer;
}

@property(nonatomic, readonly) CGFloat stepWidth;
@property(nonatomic, readonly) UIColor* color;
@property(nonatomic, readonly) CGFloat width;
@property(nonatomic, readonly) CGFloat rotation;
@property(nonatomic, readonly) CGPoint startPoint;
@property(nonatomic, readonly) CGPoint endPoint;
@property(nonatomic, readonly) CGRect bounds;
@property(nonatomic, strong) JotBufferManager* bufferManager;
@property(nonatomic, readonly) int fullByteSize;
@property(nonatomic, readonly) CGFloat extraLengthWithoutDot;

@property(nonatomic, readonly) BOOL followsMoveTo;
@property(nonatomic, readonly) CGFloat previousExtraLengthWithoutDot;
@property(nonatomic, readonly) UIColor* previousColor;
@property(nonatomic, readonly) CGFloat previousWidth;
@property(nonatomic, readonly) CGFloat previousRotation;

- (CGFloat)lengthOfElement;
- (CGFloat)angleOfStart;
- (CGFloat)angleOfEnd;
- (void)adjustStartBy:(CGPoint)adjustment;
- (UIBezierPath*)bezierPathSegment;

- (void)scaleForWidth:(CGFloat)widthRatio andHeight:(CGFloat)heightRatio NS_REQUIRES_SUPER;

@end
