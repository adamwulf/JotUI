//
//  UIColor+JotHelper.h
//  JotUI
//
//  Created by Adam Wulf on 1/2/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>


@interface UIColor (JotHelper)

/**
 * provides a nice wrapper around CGColorGetComponents
 * since the CG function may return a different number
 * of components for different colors
 */
- (void)getRGBAComponents:(GLfloat[4])components;

+ (id)colorWithDictionary:(NSDictionary*)components;

- (NSDictionary*)asDictionary;

@end
