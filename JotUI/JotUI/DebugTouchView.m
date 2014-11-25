//
//  DebugTouchView.m
//  JotUI
//
//  Created by Adam Wulf on 11/25/14.
//  Copyright (c) 2014 Adonit. All rights reserved.
//

#import "DebugTouchView.h"

@implementation DebugTouchView{
    CGPoint points[100];
    int currPoint;
}

-(id) initWithFrame:(CGRect)frame{
    if(self = [super initWithFrame:frame]){
        currPoint = 0;
    }
    return self;
}

-(void) addPoint:(CGPoint)p{
    points[currPoint] = p;
    currPoint++;
    [self setNeedsDisplayInRect:CGRectMake(p.x-5, p.y-5, 10, 10)];
}

-(void) clear{
    currPoint = 0;
    for(int i=0;i<100;i++){
        points[i] = CGPointZero;
    }
    [self setNeedsDisplay];
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
    [[UIColor redColor] setStroke];
    for(int i=0;i<100;i++){
        CGPoint p = points[i];
        if(CGRectContainsPoint(rect, p)){
            if(!CGPointEqualToPoint(p, CGPointZero)){
                UIBezierPath* circle = [UIBezierPath bezierPathWithArcCenter:p radius:3 startAngle:0 endAngle:2*M_PI clockwise:YES];
                circle.lineWidth = 3;
                [circle stroke];
            }
        }
    }
    
}


@end
