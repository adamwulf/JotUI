//
//  UIColor+JotHelper.m
//  JotUI
//
//  Created by Adam Wulf on 1/2/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import "UIColor+JotHelper.h"
#import <objc/runtime.h>


@implementation UIColor (JotHelper)

static char COLOR_COMPONENTS;

- (void)getRGBAComponents:(GLfloat[4])components {
    size_t numComponents = CGColorGetNumberOfComponents(self.CGColor);
    ;
    const CGFloat* cmps = CGColorGetComponents(self.CGColor);

    if (numComponents == 4) {
        // rgb values + alpha
        components[0] = cmps[0];
        components[1] = cmps[1];
        components[2] = cmps[2];
        components[3] = cmps[3];
    } else if (numComponents == 2) {
        // greyscale, set rgb to the same value + alpha
        components[0] = cmps[0];
        components[1] = cmps[0];
        components[2] = cmps[0];
        components[3] = cmps[1];
    }
}


- (NSMutableDictionary*)colorProperties {
    //    objc_getAssociatedObject(<#id object#>, <#const void *key#>)
    id props = objc_getAssociatedObject(self, &COLOR_COMPONENTS);
    if (!props) {
        props = [[NSMutableDictionary alloc] initWithCapacity:4];
        objc_setAssociatedObject(self, &COLOR_COMPONENTS, props, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return props;
}


+ (id)colorWithDictionary:(NSDictionary*)components {
    if (![components count]) {
        return nil;
    }
    return [UIColor colorWithRed:[[components objectForKey:@"red"] floatValue]
                           green:[[components objectForKey:@"green"] floatValue]
                            blue:[[components objectForKey:@"blue"] floatValue]
                           alpha:[[components objectForKey:@"alpha"] floatValue]];
}

- (NSDictionary*)asDictionary {
    GLfloat cmps[4];
    [self getRGBAComponents:cmps];

    NSDictionary* colorData = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:cmps[0]], @"red",
                                                                         [NSNumber numberWithFloat:cmps[1]], @"green",
                                                                         [NSNumber numberWithFloat:cmps[2]], @"blue",
                                                                         [NSNumber numberWithFloat:cmps[3]], @"alpha", nil];
    return colorData;
}

@end
