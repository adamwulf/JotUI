//
//  UIColor+JotHelper.m
//  JotUI
//
//  Created by Adam Wulf on 1/2/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "UIColor+JotHelper.h"

@implementation UIColor (JotHelper)

-(void) getRGBAComponents:(GLfloat[4])components{
    int numComponents = CGColorGetNumberOfComponents(self.CGColor);;
    const CGFloat *cmps = CGColorGetComponents(self.CGColor);
    
    if (numComponents == 4)
    {
        // rgb values + alpha
        components[0] = cmps[0];
        components[1] = cmps[1];
        components[2] = cmps[2];
        components[3] = cmps[3];
    }else if(numComponents == 2){
        // greyscale, set rgb to the same value + alpha
        components[0] = cmps[0];
        components[1] = cmps[0];
        components[2] = cmps[0];
        components[3] = cmps[1];
    }
}


@end
