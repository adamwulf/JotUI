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
    GLuint canvastexture;

    @synchronized(self){
        if([cachedTextures count]){
            JotGLTexture* reusedTexture = [cachedTextures lastObject];
            [cachedTextures removeLastObject];
//            DebugLog(@"JotTextureCache: reused texture of size: %f %f", fullSize.width, fullSize.height);
            return reusedTexture;
        }
    
//    DebugLog(@"JotTextureCache: building texture of size: %f %f", fullSize.width, fullSize.height);
    
        [JotGLContext pushCurrentContext:context];
        
        // create the texture
        glGenTextures(1, &canvastexture);
        glBindTexture(GL_TEXTURE_2D, canvastexture);
        
        //
        // http://stackoverflow.com/questions/5835656/glframebuffertexture2d-fails-on-iphone-for-certain-texture-sizes
        // these are required for non power of 2 textures on iPad 1 version of OpenGL1.1
        // otherwise, the glCheckFramebufferStatusOES will be GL_FRAMEBUFFER_UNSUPPORTED_OES
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,  fullSize.width, fullSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

        glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );

        glBindTexture(GL_TEXTURE_2D, 0);

        // we have to flush here to push all
        // the pixels to the texture so they're
        // available in the background thread's
        // context.
        // popping the context will flush
        [JotGLContext popCurrentContext];
    }

    return [[JotGLTexture alloc] initForTextureID:canvastexture withSize:fullSize];
}

-(void) returnTextureForReuse:(JotGLTexture*)texture{
    @synchronized(self){
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [texture bind];
            [texture unbind];
        });
        if([cachedTextures containsObject:texture]){
            DebugLog(@"what");
        }
        [cachedTextures addObject:texture];
//        DebugLog(@"texture returned, have %d in cache", (int) [cachedTextures count]);
    }
}


@end
