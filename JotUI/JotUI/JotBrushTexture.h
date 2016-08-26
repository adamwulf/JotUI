//
//  JotBrushTexture.h
//  JotUI
//
//  Created by Adam Wulf on 6/10/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PlistSaving.h"


@interface JotBrushTexture : NSObject <PlistSaving>

@property(readonly) UIImage* texture;
@property(readonly) NSString* name;

- (BOOL)bind;
- (void)unbind;

@end
