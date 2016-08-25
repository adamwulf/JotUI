//
//  MMTextureCache.h
//  LooseLeaf
//
//  Created by Adam Wulf on 10/22/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotGLTexture.h"


@interface JotTextureCache : NSObject

+ (JotTextureCache*)sharedManager;

- (JotGLTexture*)generateTextureForContext:(JotGLContext*)context ofSize:(CGSize)fullSize;

- (void)returnTextureForReuse:(JotGLTexture*)texture;

@end
