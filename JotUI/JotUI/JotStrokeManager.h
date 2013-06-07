//
//  JotStrokeManager.h
//  JotUI
//
//  Created by Adam Wulf on 5/27/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JotStroke.h"

@interface JotStrokeManager : NSObject

+(JotStrokeManager*) sharedInstace;

/**
 * return a stroke for the input touch only
 * if it already exists, otherwise nil
 */
-(JotStroke*) getStrokeForTouchHash:(UITouch*)touch;

/**
 * return a new or existing stroke for the
 * input touch
 */
-(JotStroke*) makeStrokeForTouchHash:(UITouch*)touch andTexture:(UIImage*)texture;

/**
 * returns true if a stroke exists and has
 * been cancelled
 */
-(BOOL) cancelStrokeForTouch:(UITouch*)touch;


/**
 * returns true if a stroke exists and has
 * been cancelled
 */
-(void) removeStrokeForTouch:(UITouch*)touch;

@end
