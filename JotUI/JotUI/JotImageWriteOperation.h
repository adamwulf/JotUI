//
//  JotImageWriteOperation.h
//  JotUI
//
//  Created by Adam Wulf on 10/30/14.
//  Copyright (c) 2014 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface JotImageWriteOperation : NSOperation

@property(nonatomic, readonly) NSString* path;
@property(nonatomic, readonly) UIImage* image;

- (instancetype)init NS_UNAVAILABLE;

- (id)initWithImage:(UIImage*)image andPath:(NSString*)path andNotifyBlock:(void (^)(JotImageWriteOperation*))block;

@end
