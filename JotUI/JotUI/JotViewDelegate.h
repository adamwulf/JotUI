//
//  JotViewDelegate.h
//  JotUI
//
//  Created by Adam Wulf on 12/12/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractBezierPathElement.h"
#import "JotBrushTexture.h"

@class JotView, JotTouch, JotStroke;

@protocol JotViewDelegate

/**
 * The texture to use for the new stroke
 */
- (JotBrushTexture*)textureForStroke;

/**
 * The distance between dots for the new brush
 */
- (CGFloat)stepWidthForStroke;

/**
 * YES if the current pen can rotate its texture
 * NO otherwise
 */
- (BOOL)supportsRotation;

/**
 * for the input touch, what is the desired point
 * width that should show on screen?
 *
 * Note - this is point width, not pixel width,
 * so the value for low vs high resolution screens
 * should be the same
 */
- (CGFloat)widthForCoalescedTouch:(UITouch*)coalescedTouch fromTouch:(UITouch*)touch inJotView:(JotView*)jotView;

/**
 * what is the desired color for the touch
 * at its location on screen. the returned color
 * can be RGBA, and will be interpolated between
 * touches along a line.
 *
 * return nil to erase instead of apply a color
 */
- (UIColor*)colorForCoalescedTouch:(UITouch*)coalescedTouch fromTouch:(UITouch*)touch inJotView:(JotView*)jotView;

/**
 * defines how smooth the transition should be to
 * the input touch's location
 *
 * a value of 0 will cause sharp points at each touch location,
 * a value of 1 will be very rounded at each touch point
 * values > 1 or < 0 will be knotted or loopy at each touch point
 */
- (CGFloat)smoothnessForCoalescedTouch:(UITouch*)coalescedTouch fromTouch:(UITouch*)touch inJotView:(JotView*)jotView;

/**
 * notifies the delegate that the input segments will be added to the stroke,
 * and allows the delegate to return a modified array of elements
 * to add instead
 */
- (NSArray*)willAddElements:(NSArray*)elements toStroke:(JotStroke*)stroke fromPreviousElement:(AbstractBezierPathElement*)previousElement inJotView:(JotView*)jotView;

/**
 * a notification that a new stroke is about to begin
 * with the input touch
 */
- (BOOL)willBeginStrokeWithCoalescedTouch:(UITouch*)coalescedTouch fromTouch:(UITouch*)touch inJotView:(JotView*)jotView;

/**
 * a notification that the input is moving to the
 * next touch
 */
- (void)willMoveStrokeWithCoalescedTouch:(UITouch*)coalescedTouch fromTouch:(UITouch*)touch inJotView:(JotView*)jotView;

/**
 * a notification that the input will end the
 * stroke
 */
- (void)willEndStrokeWithCoalescedTouch:(UITouch*)coalescedTouch fromTouch:(UITouch*)touch shortStrokeEnding:(BOOL)shortStrokeEnding inJotView:(JotView*)jotView;

/**
 * a notification that the touch has ended. For
 * any ending touch, a willMoveStrokeWithTouch:
 * will also be called before this ending call
 */
- (void)didEndStrokeWithCoalescedTouch:(UITouch*)coalescedTouch fromTouch:(UITouch*)touch inJotView:(JotView*)jotView;

/**
 * the stroke for the input touch will been cancelled.
 */
- (void)willCancelStroke:(JotStroke*)stroke withCoalescedTouch:(UITouch*)coalescedTouch fromTouch:(UITouch*)touch inJotView:(JotView*)jotView;

/**
 * the stroke for the input touch has been cancelled.
 */
- (void)didCancelStroke:(JotStroke*)stroke withCoalescedTouch:(UITouch*)coalescedTouch fromTouch:(UITouch*)touch inJotView:(JotView*)jotView;

@end
