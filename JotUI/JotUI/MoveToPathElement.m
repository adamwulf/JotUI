//
//  DotSegment.m
//  JotUI
//
//  Created by Adam Wulf on 12/19/12.
//  Copyright (c) 2012 Milestone Made. All rights reserved.
//

#import "MoveToPathElement.h"
#import "AbstractBezierPathElement-Protected.h"


@implementation MoveToPathElement {
    // cache the hash, since it's expenseive to calculate
    NSUInteger _hashCache;
}

- (id)initWithMoveTo:(CGPoint)point {
    if (self = [super initWithStart:point]) {
        NSUInteger prime = 31;
        _hashCache = 1;
        _hashCache = prime * _hashCache + _startPoint.x;
        _hashCache = prime * _hashCache + _startPoint.y;
    }
    return self;
}

+ (id)elementWithMoveTo:(CGPoint)point {
    return [[MoveToPathElement alloc] initWithMoveTo:point];
}

- (int)fullByteSize {
    return 0;
}

/**
 * we're just 1 point, so we have zero length
 */
- (CGFloat)lengthOfElement {
    return 0;
}

- (CGFloat)angleOfStart {
    return 0;
}

- (CGFloat)angleOfEnd {
    return 0;
}

- (CGRect)bounds {
    return CGRectInset(CGRectMake(_startPoint.x, _startPoint.y, 0, 0), -_width, -_width);
}

- (CGPoint)endPoint {
    return self.startPoint;
}

- (void)adjustStartBy:(CGPoint)adjustment {
    _startPoint = CGPointMake(_startPoint.x + adjustment.x, _startPoint.y + adjustment.y);
}

/**
 * only 1 step to show our single point
 */
- (NSInteger)numberOfSteps {
    return 0;
}

- (NSInteger)numberOfBytes {
    return 0;
}

- (struct ColorfulVertex*)generatedVertexArrayForScale:(CGFloat)scale {
    return NULL;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"[Move to: %f,%f]", _startPoint.x, _startPoint.y];
}

#pragma mark - PlistSaving

- (id)initFromDictionary:(NSDictionary*)dictionary {
    if (self = [super initFromDictionary:dictionary]) {
        NSUInteger prime = 31;
        _hashCache = 1;
        _hashCache = prime * _hashCache + _startPoint.x;
        _hashCache = prime * _hashCache + _startPoint.y;

        CGFloat currentScale = [[dictionary objectForKey:@"scale"] floatValue];
        if (currentScale != _scaleOfVertexBuffer) {
            // the scale of the cached data in the dictionary is
            // different than the scael of the data that we need.
            // zero this out and it'll regenerate with the
            // correct scale on demand
            _scaleOfVertexBuffer = 0;
            _dataVertexBuffer = nil;
        }
    }
    return self;
}

- (UIBezierPath*)bezierPathSegment {
    UIBezierPath* strokePath = [UIBezierPath bezierPath];
    [strokePath moveToPoint:self.startPoint];
    return strokePath;
}


#pragma mark - hashing and equality

- (NSUInteger)hash {
    return _hashCache;
}

- (BOOL)isEqual:(id)object {
    return self == object || [self hash] == [object hash];
}

@end
