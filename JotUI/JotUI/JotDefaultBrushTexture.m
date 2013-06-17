//
//  JotDefaultBrushTexture.m
//  JotUI
//
//  Created by Adam Wulf on 6/10/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotDefaultBrushTexture.h"

@implementation JotDefaultBrushTexture{
    UIImage* textureCache;
}

-(UIImage*) texture{
    if(!textureCache){
        UIGraphicsBeginImageContext(CGSizeMake(32, 32));
        CGContextRef defBrushTextureContext = UIGraphicsGetCurrentContext();
        UIGraphicsPushContext(defBrushTextureContext);
        
        size_t num_locations = 3;
        CGFloat locations[3] = { 0.0, 0.7, 1.0 };
        CGFloat components[12] = { 1.0,1.0,1.0, 1.0,
            1.0,1.0,1.0, 1.0,
            1.0,1.0,1.0, 0.0 };
        CGColorSpaceRef myColorspace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef myGradient = CGGradientCreateWithColorComponents (myColorspace, components, locations, num_locations);
        
        CGPoint myCentrePoint = CGPointMake(16, 16);
        float myRadius = 10;
        
        CGContextDrawRadialGradient (UIGraphicsGetCurrentContext(), myGradient, myCentrePoint,
                                     0, myCentrePoint, myRadius,
                                     kCGGradientDrawsAfterEndLocation);
        
        UIGraphicsPopContext();
        
        textureCache = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
    }
    
    return textureCache;
}

#pragma mark - PlistSaving

-(NSDictionary*) asDictionary{
    return [NSDictionary dictionaryWithObject:self.name forKey:@"class"];
}

-(id) initFromDictionary:(NSDictionary*)dictionary{
    return [super init];
}


#pragma mark - Singleton

static JotDefaultBrushTexture* _instance = nil;

-(id) init{
    if(_instance) return _instance;
    if((_instance = [super init])){
        // noop
    }
    return _instance;
}

+(JotBrushTexture*) sharedInstace{
    if(!_instance){
        _instance = [[JotDefaultBrushTexture alloc] init];
    }
    return _instance;
}



@end
