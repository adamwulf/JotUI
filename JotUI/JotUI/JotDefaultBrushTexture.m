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
        UIGraphicsBeginImageContext(CGSizeMake(64, 64));
        CGContextRef defBrushTextureContext = UIGraphicsGetCurrentContext();
        UIGraphicsPushContext(defBrushTextureContext);
        
        size_t num_locations = 3;
        CGFloat locations[3] = { 0.0, 0.7, 1.0 };
        CGFloat components[12] = { 1.0,1.0,1.0, 1.0,
            1.0,1.0,1.0, 1.0,
            1.0,1.0,1.0, 0.0 };
        CGColorSpaceRef myColorspace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef myGradient = CGGradientCreateWithColorComponents (myColorspace, components, locations, num_locations);
        
        CGPoint myCentrePoint = CGPointMake(32, 32);
        float myRadius = 20;
        
        CGContextDrawRadialGradient (UIGraphicsGetCurrentContext(), myGradient, myCentrePoint,
                                     0, myCentrePoint, myRadius,
                                     kCGGradientDrawsAfterEndLocation);
        
        UIGraphicsPopContext();
        
        textureCache = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
    }
    
    return textureCache;
}

-(NSString*) name{
    return @"JotDefaultBrushTexture";
}



#pragma mark - NSCoder

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@"JotDefaultBrushTexture" forKey:@"name"];
    [coder encodeObject:self.texture forKey:@"texture"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        textureCache = [coder decodeObjectForKey:@"texture"];
    }
    return self;
}


#pragma mark - PlistSaving

-(NSDictionary*) asDictionary{
    return [NSDictionary dictionaryWithObject:@"JotDefaultBrushTexture" forKey:@"class"];
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
