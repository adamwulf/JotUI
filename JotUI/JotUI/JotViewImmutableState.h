//
//  JotViewImmutableState.h
//  JotUI
//
//  Created by Adam Wulf on 6/22/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface JotViewImmutableState : NSObject

@property(nonatomic, assign) BOOL mustOverwriteAllStrokeFiles;

- (void)writeToDisk:(NSString*)plistPath;

// a unique value that defines the current undo state.
// if this value is the same as when this view was exported,
// then nothing has changed that would affect the output image
- (NSUInteger)undoHash;

@end
