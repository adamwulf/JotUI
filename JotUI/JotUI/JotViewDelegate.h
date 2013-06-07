//
//  JotViewDelegate.h
//  JotUI
//
//  Created by Adam Wulf on 12/12/12.
//  Copyright (c) 2012 Adonit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractBezierPathElement.h"

@class JotTouch;

@protocol JotViewDelegate <NSObject>

/**
 * for the input touch, what is the desired point
 * width that should show on screen?
 *
 * Note - this is point width, not pixel width,
 * so the value for low vs high resolution screens
 * should be the same
 */
- (CGFloat) widthForTouch:(JotTouch*)touch;

/**
 * what is the desired color for the touch
 * at its location on screen. the returned color
 * can be RGBA, and will be interpolated between
 * touches along a line.
 *
 * return nil to erase instead of apply a color
 */
- (UIColor*) colorForTouch:(JotTouch*)touch;

/**
 * defines how smooth the transition should be to
 * the input touch's location
 *
 * a value of 0 will cause sharp points at each touch location,
 * a value of 1 will be very rounded at each touch point
 * values > 1 or < 0 will be knotted or loopy at each touch point
 */
- (CGFloat) smoothnessForTouch:(JotTouch*)touch;

/**
 * defines to what angle the stroke will rotate during
 * this segment
 *
 * a value of 0 will cause sharp points at each touch location,
 * a value of 1 will be very rounded at each touch point
 * values > 1 or < 0 will be knotted or loopy at each touch point
 */
- (CGFloat) rotationForSegment:(AbstractBezierPathElement*)segment fromPreviousSegment:(AbstractBezierPathElement*)previousSegment;

/**
 * a notification that a new stroke is about to begin
 * with the input touch
 */
- (void) willBeginStrokeWithTouch:(JotTouch*)touch;

/**
 * a notification that the input is moving to the
 * next touch
 */
- (void) willMoveStrokeWithTouch:(JotTouch*)touch;

/**
 * a notification that the touch has ended. For
 * any ending touch, a willMoveStrokeWithTouch:
 * will also be called before this ending call
 */
- (void) didEndStrokeWithTouch:(JotTouch*)touch;

/**
 * the stroke for the input touch has been cancelled.
 */
- (void) didCancelStrokeWithTouch:(JotTouch*)touch;

@optional

/**
 * if you have additional gestures on this JotView,
 * then these delegate methods will hint at when
 * may be a good time to enable or disable these
 * extra gestures.
 *
 * these hints are forwarded from the JotTouchSDK
 * and suggest when the user is drawing or resting
 * their palm on the screen, and so disabling your
 * additional gestures here will help reduce false
 * positives
 */
- (void) jotSuggestsToDisableGestures;

- (void) jotSuggestsToEnableGestures;

@end
