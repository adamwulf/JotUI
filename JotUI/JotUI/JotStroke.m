//
//  JotStroke.m
//  JotTouchExample
//
//  Created by Adam Wulf on 1/9/13.
//  Copyright (c) 2013 Adonit, LLC. All rights reserved.
//

#import "JotStroke.h"
#import "SegmentSmoother.h"
#import "AbstractBezierPathElement.h"
#import "AbstractBezierPathElement-Protected.h"
#import "JotDefaultBrushTexture.h"
#import "NSArray+JotMapReduce.h"

@implementation JotStroke

@synthesize segments;
@synthesize segmentSmoother;
@synthesize texture;
@synthesize delegate;


-(id) initWithTexture:(JotBrushTexture*)_texture{
    if(self = [super init]){
        segments = [NSMutableArray array];
        segmentSmoother = [[SegmentSmoother alloc] init];
        texture = _texture;
    }
    return self;
}


/**
 * returns YES if the point modified the stroke by adding a new segment,
 * or NO if the segment is unmodified because there are still too few
 * points to interpolate
 */
-(BOOL) addPoint:(CGPoint)point withWidth:(CGFloat)width andColor:(UIColor*)color andSmoothness:(CGFloat)smoothFactor{
    AbstractBezierPathElement* element = [segmentSmoother addPoint:point andSmoothness:smoothFactor];
    
    if(!element) return NO;
    
    element.color = color;
    element.width = width;
    [segments addObject:element];
    
    return YES;
}

-(void) cancel{
    [self.delegate jotStrokeWasCancelled:self];
}


#pragma mark - NSCoder

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:segmentSmoother forKey:@"segmentSmoother"];
    [coder encodeObject:segments forKey:@"segments"];
    [coder encodeObject:texture forKey:@"texture"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        segmentSmoother = [coder decodeObjectForKey:@"segmentSmoother"];
        segments = [coder decodeObjectForKey:@"segments"];
        texture = [coder decodeObjectForKey:@"texture"];
    }
    return self;
}



@end
