//
//  MMTextureCache.m
//  LooseLeaf
//
//  Created by Adam Wulf on 10/22/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import "JotTextureCache.h"
#import "JotGLContext.h"


@interface JotGLTexture (Lock)

- (BOOL)isLocked;

@end


@implementation JotTextureCache {
    NSMutableArray* cachedTextures;
}

- (id)init {
    if (self = [super init]) {
        cachedTextures = [NSMutableArray array];
    }
    return self;
}

+ (JotTextureCache*)sharedManager {
    static dispatch_once_t onceToken;
    static JotTextureCache* manager;
    dispatch_once(&onceToken, ^{
        manager = [[JotTextureCache alloc] init];
    });
    return manager;
}

- (JotGLTexture*)generateTextureForContext:(JotGLContext*)context ofSize:(CGSize)fullSize {
    __block GLuint canvastexture = 0;

    @synchronized(self) {
        if ([cachedTextures count]) {
            CGFloat targetPxCount = fullSize.width * fullSize.height;
            for (NSInteger index = 0; index < [cachedTextures count]; index++) {
                JotGLTexture* reusedTexture = cachedTextures[index];
                CGFloat reusedPxCount = reusedTexture.pixelSize.width * reusedTexture.pixelSize.height;
                if (reusedPxCount >= targetPxCount) {
                    // Only return a cached texture if it could fit the requested texture size
                    // in it's allocated size
                    [cachedTextures removeObject:reusedTexture];
                    return reusedTexture;
                }
            }
        }

        [context runBlock:^{
            canvastexture = [context generateTextureForSize:fullSize withBytes:NULL];
            // we have to flush here to push all
            // the pixels to the texture so they're
            // available in the background thread's
            // context.
            // popping the context will flush
        }];
    }

    return [[JotGLTexture alloc] initForTextureID:canvastexture withSize:fullSize];
}

- (void)returnTextureForReuse:(JotGLTexture*)texture {
    @synchronized(self) {
        if ([texture isLocked]) {
            @throw [NSException exceptionWithName:@"TextureCacheException" reason:@"Caching locked texture" userInfo:nil];
        }
        if ([cachedTextures containsObject:texture]) {
            @throw [NSException exceptionWithName:@"TextureCacheException" reason:@"Recaching already cached texture" userInfo:nil];
        }
        [cachedTextures addObject:texture];
        //        DebugLog(@"texture returned, have %d in cache", (int) [cachedTextures count]);
    }
}


@end
