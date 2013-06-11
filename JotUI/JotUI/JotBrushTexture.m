//
//  JotBrushTexture.m
//  JotUI
//
//  Created by Adam Wulf on 6/10/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotBrushTexture.h"

#define kAbstractMethodException [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil]


@implementation JotBrushTexture

-(UIImage*) texture{
    @throw kAbstractMethodException;
}

-(NSString*) name{
    @throw kAbstractMethodException;
}


#pragma mark - PlistSaving

-(NSDictionary*) asDictionary{
    return [NSDictionary dictionaryWithObject:NSStringFromClass([self class]) forKey:@"class"];
}

-(id) initFromDictionary:(NSDictionary*)dictionary{
    NSString* className = [dictionary objectForKey:@"class"];
    Class clz = NSClassFromString(className);
    return [clz sharedInstace];
}

#pragma mark - Singleton

+(JotBrushTexture*) sharedInstace{
    @throw kAbstractMethodException;
}


@end
