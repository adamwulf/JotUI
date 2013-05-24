//
//  AbstractSegment.h
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifndef AbstractBezierPathElement_H
#define AbstractBezierPathElement_H

struct Vertex{
    GLfloat Position[2];    // x,y position
    GLfloat Color [4];      // rgba color
    GLfloat Texture[2];    // x,y texture coord
    //    GLfloat Size;           // pixel size
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
#define kBrushStepSize		1

@interface AbstractBezierPathElement : NSObject{
    CGPoint startPoint;
    CGFloat width;
    UIColor* color;
    CGFloat rotation;
    
    struct Vertex* vertexBuffer;
    CGFloat scaleOfVertexBuffer;
}

@property (nonatomic, readonly) UIColor* color;
@property (nonatomic, readonly) CGFloat width;
@property (nonatomic, readonly) CGPoint startPoint;
@property (nonatomic, readonly) CGFloat  rotation;

-(CGFloat) lengthOfElement;
-(CGFloat) angleOfStart;
-(CGFloat) angleOfEnd;

@end
