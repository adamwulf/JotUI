//
//  Marker.m
//  jotuiexample
//
//  Created by Adam Wulf on 12/18/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import "Marker.h"
#import "SquareBrushTexture.h"


@implementation Marker

- (id)initWithMinSize:(CGFloat)_minSize andMaxSize:(CGFloat)_maxSize andMinAlpha:(CGFloat)_minAlpha andMaxAlpha:(CGFloat)_maxAlpha {
    if (self = [super initWithMinSize:_minSize andMaxSize:_maxSize andMinAlpha:_minAlpha andMaxAlpha:_maxAlpha]) {
        // noop
    }
    return self;
}

- (id)init {
    return [self initWithMinSize:40.0 andMaxSize:60.0 andMinAlpha:.3 andMaxAlpha:.5];
}

- (JotBrushTexture*)textureForStroke {
    return [SquareBrushTexture sharedInstance];
}

@end
