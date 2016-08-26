//
//  FilledPathElement.h
//  JotUI
//
//  Created by Adam Wulf on 2/5/14.
//  Copyright (c) 2014 Milestone Made. All rights reserved.
//

#import <JotUI/JotUI.h>


@interface FilledPathElement : AbstractBezierPathElement

+ (id)elementWithPath:(UIBezierPath*)path andP1:(CGPoint)p1 andP2:(CGPoint)p2 andP3:(CGPoint)p3 andP4:(CGPoint)p4 andSize:(CGSize)size;

@end
