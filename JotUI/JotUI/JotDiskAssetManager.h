//
//  JotDiskAssetManager.h
//  JotUI
//
//  Created by Adam Wulf on 10/29/14.
//  Copyright (c) 2014 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface JotDiskAssetManager : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (JotDiskAssetManager*)sharedManager;

+ (UIImage*)imageWithContentsOfFile:(NSString*)path;

- (void)writeImage:(UIImage*)image toPath:(NSString*)path;

- (void)blockUntilCompletedForPath:(NSString*)path;

- (void)blockUntilCompletedForDirectory:(NSString*)dirPath;

- (void)blockUntilAllWritesHaveFinished;

@end
