//
//  JotBrushTexture.h
//  JotUI
//
//  Created by Adam Wulf on 6/10/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface JotBrushTexture : NSObject<NSCoding>

@property (readonly) UIImage* texture;
@property (readonly) NSString* name;

+(JotBrushTexture*) sharedInstace;

@end
