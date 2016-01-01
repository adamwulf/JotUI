//
//  JotSharedBrushTexture.m
//  JotUI
//
//  Created by Adam Wulf on 10/27/14.
//  Copyright (c) 2014 Adonit. All rights reserved.
//

#import "JotSharedBrushTexture.h"

@implementation JotSharedBrushTexture{
    UIImage* textureCache;
}

static int jotBrushCount = 0;

-(id) init{
    if(self = [super init]){
        jotBrushCount++;
//        NSLog(@"built brush: %d", jotBrushCount);
    }
    return self;
}

-(void) dealloc{
    jotBrushCount--;
//    NSLog(@"destroyed brush: %d", jotBrushCount);
}

-(UIImage*) texture{
    if(!textureCache){
        UIGraphicsBeginImageContext(CGSizeMake(64, 64));
        CGContextRef defBrushTextureContext = UIGraphicsGetCurrentContext();
        UIGraphicsPushContext(defBrushTextureContext);
        
        size_t num_locations = 3;
        CGFloat locations[3] = { 0.0, 0.2, 1.0 };
        CGFloat components[12] = { 1.0,1.0,1.0, 1.0,
            1.0,1.0,1.0, 1.0,
            1.0,1.0,1.0, 0.0 };
        CGColorSpaceRef myColorspace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef myGradient = CGGradientCreateWithColorComponents (myColorspace, components, locations, num_locations);
        
        CGPoint myCentrePoint = CGPointMake(32, 32);
        float myRadius = 30;
        
        CGContextDrawRadialGradient (UIGraphicsGetCurrentContext(), myGradient, myCentrePoint,
                                     0, myCentrePoint, myRadius,
                                     kCGGradientDrawsAfterEndLocation);
        
        CGGradientRelease(myGradient);
        CGColorSpaceRelease(myColorspace);
        
        UIGraphicsPopContext();
        
        textureCache = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
    }
    
    return textureCache;
}

@end
