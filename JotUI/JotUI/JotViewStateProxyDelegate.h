//
//  JotViewStateProxyDelegate.h
//  LooseLeaf
//
//  Created by Adam Wulf on 9/24/13.
//  Copyright (c) 2013 Milestone Made, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class JotViewStateProxy;

@protocol JotViewStateProxyDelegate

@property(nonatomic, readonly) NSString* jotViewStateInkPath;

@property(nonatomic, readonly) NSString* jotViewStatePlistPath;

- (void)didLoadState:(JotViewStateProxy*)state;

- (void)didUnloadState:(JotViewStateProxy*)state;

@end
