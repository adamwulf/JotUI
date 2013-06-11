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


#pragma mark - NSCoder

- (void)encodeWithCoder:(NSCoder *)coder {
    @throw kAbstractMethodException;
}

- (id)initWithCoder:(NSCoder *)coder {
    @throw kAbstractMethodException;
}

#pragma mark - Singleton

+(JotBrushTexture*) sharedInstace{
    @throw kAbstractMethodException;
}


@end
