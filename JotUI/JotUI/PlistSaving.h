//
//  PlistSaving.h
//  JotUI
//
//  Created by Adam Wulf on 6/10/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PlistSaving <NSObject>

- (NSDictionary*)asDictionary;

- (id)initFromDictionary:(NSDictionary*)dictionary;

@end
