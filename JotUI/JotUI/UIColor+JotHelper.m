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


+(id) colorWithDictionary:(NSDictionary*)components{
    return [UIColor colorWithRed:[[components objectForKey:@"red"] floatValue]
                           green:[[components objectForKey:@"green"] floatValue]
                            blue:[[components objectForKey:@"blue"] floatValue]
                           alpha:[[components objectForKey:@"alpha"] floatValue]];
}

-(NSDictionary*) asDictionary{
    CGFloat red, blue, green, alpha;
    red = blue = green = alpha = 0;
    [self getRed:&red green:&green blue:&blue alpha:&alpha];
    
    NSDictionary *colorData = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:red], @"red",
                               [NSNumber numberWithFloat:green], @"green",
                               [NSNumber numberWithFloat:blue], @"blue",
                               [NSNumber numberWithFloat:alpha], @"alpha", nil];
    return colorData;
}

@end
