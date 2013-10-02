//
//  JotBufferManager.h
//  JotUI
//
//  Created by Adam Wulf on 7/20/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>

@class JotBufferVBO;

@interface JotBufferManager : NSObject

+(JotBufferManager*) sharedInstace;

+(NSInteger) cacheNumberForData:(NSData*)data;

-(JotBufferVBO*) bufferWithData:(NSData*)data;

-(void) recycleBuffer:(JotBufferVBO*)buffer;

-(void) resetCacheStats;

@end
