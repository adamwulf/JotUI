//
//  UIColor+JotHelper.m
//  JotUI
//
//  Created by Adam Wulf on 1/2/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "UIColor+JotHelper.h"

@implementation UIColor (JotHelper)

-(void) getRGBAComponents:(GLubyte[4])components{
    int numComponents = CGColorGetNumberOfComponents(self.CGColor);;
    const CGFloat *cmps = CGColorGetComponents(self.CGColor);
    
    if (numComponents == 4)
    {
        // rgb values + alpha
        components[0] = (GLubyte)lroundf(cmps[0]*255);
        components[1] = (GLubyte)lroundf(cmps[1]*255);
        components[2] = (GLubyte)lroundf(cmps[2]*255);
        components[3] = (GLubyte)lroundf(cmps[3]*255);
    }else if(numComponents == 2){
        // greyscale, set rgb to the same value + alpha
        components[0] = (GLubyte)lroundf(cmps[0]*255);
        components[1] = (GLubyte)lroundf(cmps[0]*255);
        components[2] = (GLubyte)lroundf(cmps[0]*255);
        components[3] = (GLubyte)lroundf(cmps[1]*255);
    }
}


@end
