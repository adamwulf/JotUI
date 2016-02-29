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

-(id) initWithImage:(UIImage *)texture{
    if(self = [super init]){
        textureCache = texture;
    }
    return self;
}

@end
