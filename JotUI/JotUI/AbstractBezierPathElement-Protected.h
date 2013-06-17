//
//  AbstractBezierPathElement-Protected.h
//  JotUI
//
//  Created by Adam Wulf on 5/22/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#ifndef JotUI_AbstractBezierPathElement_Protected_h
#define JotUI_AbstractBezierPathElement_Protected_h

@interface AbstractBezierPathElement ()

@property (nonatomic, strong) UIColor* color;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat  rotation;

-(id) initWithStart:(CGPoint)point;

-(NSInteger) numberOfVerticesPerStep;

-(NSInteger) numberOfIndicesPerStep;

-(NSInteger) numberOfSteps;

-(int) numberOfBytes;

-(struct Vertex*) generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale;

-(NSArray*) arrayOfPositionsForPoint:(CGPoint)point
                            andWidth:(CGFloat)stepWidth
                         andRotation:(CGFloat)stepRotation;

-(CGFloat) angleBetweenPoint:(CGPoint) point1 andPoint:(CGPoint)point2;

-(BOOL) bind;

-(void) unbind;

-(void) draw;

@end


#endif
