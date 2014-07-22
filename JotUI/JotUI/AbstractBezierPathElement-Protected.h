//
//  AbstractBezierPathElement-Protected.h
//  JotUI
//
//  Created by Adam Wulf on 5/22/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#ifndef JotUI_AbstractBezierPathElement_Protected_h
#define JotUI_AbstractBezierPathElement_Protected_h

#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#define printOpenGLError() printOglError(__FILE__, __LINE__)

int printOglError(char *file, int line);

@interface AbstractBezierPathElement ()

@property (nonatomic, strong) UIColor* color;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat extraLengthWithoutDot;

-(id) initWithStart:(CGPoint)point;

-(NSInteger) numberOfVerticesPerStep;

-(NSInteger) numberOfStepsGivenPreviousElement:(AbstractBezierPathElement *)previousElement;

-(NSInteger) numberOfVerticesGivenPreviousElement:(AbstractBezierPathElement *)previousElement;

-(NSInteger) numberOfBytesGivenPreviousElement:(AbstractBezierPathElement*)previousElement;

-(void) validateDataGivenPreviousElement:(AbstractBezierPathElement*)previousElement;

-(struct ColorfulVertex*) generatedVertexArrayWithPreviousElement:(AbstractBezierPathElement*)previousElement forScale:(CGFloat)scale;

-(CGFloat) angleBetweenPoint:(CGPoint) point1 andPoint:(CGPoint)point2;

-(BOOL) bind;

-(void) unbind;

-(void) drawGivenPreviousElement:(AbstractBezierPathElement *)previousElement;

-(void) loadDataIntoVBOIfNeeded;

@end


#endif
