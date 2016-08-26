//
//  JotHighlighterBrushTexture.m
//  JotUI
//
//  Created by Adam Wulf on 2/29/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#import "JotHighlighterBrushTexture.h"
#import "JotSharedBrushTexture.h"
#import "UIImage+BrushTextures.h"


@implementation JotHighlighterBrushTexture

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
    JotBrushTexture* texture = [currContext.contextProperties objectForKey:@"highlighterTexture"];
    if (!texture) {
        @throw [NSException exceptionWithName:@"JotGLContextException" reason:@"Cannot unbind unbuilt brush texture" userInfo:nil];
    }
    [texture unbind];
}

#pragma mark - Singleton

static JotHighlighterBrushTexture* _instance = nil;

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
        _instance = [[JotHighlighterBrushTexture alloc] init];
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
    JotSharedBrushTexture* texture = [currContext.contextProperties objectForKey:@"highlighterTexture"];
    if (!texture) {
        NSBundle* bundle = [NSBundle bundleForClass:[JotView class]];
        UIImage* highlighter = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"highlighter" ofType:@"png"]];
        texture = [[JotSharedBrushTexture alloc] initWithImage:highlighter];
        [currContext.contextProperties setObject:texture forKey:@"highlighterTexture"];
    }
    return texture;
}

@end
