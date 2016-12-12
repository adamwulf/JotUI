//
//  MMDataCache.h
//  JotUI
//
//  Created by Adam Wulf on 12/11/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MMDataCache : NSObject

+ (MMDataCache*)sharedCache;


- (NSData*)dataOfSize:(NSUInteger)byteSize;

- (void)returnDataToCache:(NSData*)data;

@end
