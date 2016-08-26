//
//  JotBufferManager.h
//  JotUI
//
//  Created by Adam Wulf on 7/20/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kVBOCacheSize @"VBO Cache Size"
#define kVBOCacheNumSizeFmt @"VBO[%d]"


@class JotBufferVBO, OpenGLVBO;


@interface JotBufferManager : NSObject

+ (JotBufferManager*)sharedInstance;

+ (NSInteger)cacheNumberForData:(NSData*)data;

- (JotBufferVBO*)bufferWithData:(NSData*)data;

- (void)recycleBuffer:(JotBufferVBO*)buffer;

- (void)openGLBufferHasDied:(OpenGLVBO*)openGLVBO;

- (NSDictionary*)cacheMemoryStats;

@end
