//
//  JotDefaultBrushTexture.m
//  JotUI
//
//  Created by Adam Wulf on 6/10/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import "JotDefaultBrushTexture.h"
#import "JotGLContext.h"
#import "JotSharedBrushTexture.h"
#import "UIImage+BrushTextures.h"


@implementation JotDefaultBrushTexture

#pragma mark - PlistSaving

- (NSDictionary*)asDictionary {
    return [NSDictionary dictionaryWithObject:NSStringFromClass([self class]) forKey:@"class"];
}

- (id)initFromDictionary:(NSDictionary*)dictionary {
    NSString* className = [dictionary objectForKey:@"class"];
    Class clz = NSClassFromString(className);
    return [[clz alloc] init];
}


#pragma mark - Singleton

- (UIImage*)texture {
    return [[self brushTexture] texture];
}

- (NSString*)name {
    return [[self brushTexture] name];
}

- (BOOL)bind {
    return [[self brushTexture] bind];
}

- (void)unbind {
    JotGLContext* currContext = (JotGLContext*)[JotGLContext currentContext];
    if (!currContext) {
        @throw [NSException exceptionWithName:@"NilGLContextException" reason:@"Cannot bind texture to nil gl context" userInfo:nil];
    }
    if (![currContext isKindOfClass:[JotGLContext class]]) {
        @throw [NSException exceptionWithName:@"JotGLContextException" reason:@"Current GL Context must be JotGLContext" userInfo:nil];
    }
    JotBrushTexture* texture = [currContext.contextProperties objectForKey:@"brushTexture"];
    if (!texture) {
        @throw [NSException exceptionWithName:@"JotGLContextException" reason:@"Cannot unbind unbuilt brush texture" userInfo:nil];
    }
    [texture unbind];
}

#pragma mark - Singleton

static JotDefaultBrushTexture* _instance = nil;

- (id)init {
    if (_instance)
        return _instance;
    if ((_instance = [super init])) {
        // noop
    }
    return _instance;
}

+ (JotBrushTexture*)sharedInstance {
    if (!_instance) {
        _instance = [[JotDefaultBrushTexture alloc] init];
    }
    return _instance;
}


#pragma mark - Private

- (JotSharedBrushTexture*)brushTexture {
    JotGLContext* currContext = (JotGLContext*)[JotGLContext currentContext];
    if (!currContext) {
        @throw [NSException exceptionWithName:@"NilGLContextException" reason:@"Cannot bind texture to nil gl context" userInfo:nil];
    }
    if (![currContext isKindOfClass:[JotGLContext class]]) {
        @throw [NSException exceptionWithName:@"JotGLContextException" reason:@"Current GL Context must be JotGLContext" userInfo:nil];
    }
    JotSharedBrushTexture* texture = [currContext.contextProperties objectForKey:@"brushTexture"];
    if (!texture) {
        texture = [[JotSharedBrushTexture alloc] initWithImage:[UIImage circleBrushTexture]];
        [currContext.contextProperties setObject:texture forKey:@"brushTexture"];
    }
    return texture;
}

@end
