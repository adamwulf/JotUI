//
//  MMTextureCache.m
//  LooseLeaf
//
//  Created by Adam Wulf on 10/22/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import "JotTextureCache.h"
#import "JotGLContext.h"

@implementation JotTextureCache{
    NSMutableArray* cachedTextures;
}

-(id) init{
    if(self = [super init]){
        cachedTextures = [NSMutableArray array];
    }
    return self;
}

+ (JotTextureCache *) sharedManager {
    static dispatch_once_t onceToken;
    static JotTextureCache *manager;
    dispatch_once(&onceToken, ^{
        manager = [[JotTextureCache alloc] init];
    });
    return manager;
}

-(JotGLTexture*) generateTextureForContext:(JotGLContext*)context ofSize:(CGSize)fullSize{
    __block GLuint canvastexture = 0;

    @synchronized(self){
        if([cachedTextures count]){
            JotGLTexture* reusedTexture = [cachedTextures lastObject];
            [cachedTextures removeLastObject];
//            DebugLog(@"JotTextureCache: reused texture of size: %f %f", fullSize.width, fullSize.height);
            return reusedTexture;
        }
    
//    DebugLog(@"JotTextureCache: building texture of size: %f %f", fullSize.width, fullSize.height);
    
        [context runBlock:^{
            // create the texture
            
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

-(void) returnTextureForReuse:(JotGLTexture*)texture{
    @synchronized(self){
        if([cachedTextures containsObject:texture]){
            DebugLog(@"what");
        }
        [cachedTextures addObject:texture];
//        DebugLog(@"texture returned, have %d in cache", (int) [cachedTextures count]);
    }
}


@end
