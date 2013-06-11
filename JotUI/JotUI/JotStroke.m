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


#pragma mark - PlistSaving

-(NSDictionary*) asDictionary{
    return [NSDictionary dictionaryWithObjectsAndKeys:@"JotStroke", @"class",
            [segmentSmoother asDictionary], @"segmentSmoother",
            [segments jotMapWithSelector:@selector(asDictionary)], @"segments",
            [texture asDictionary], @"texture", nil];
}

-(id) initFromDictionary:(NSDictionary*)dictionary{
    if(self = [super init]){
        segmentSmoother = [[SegmentSmoother alloc] initFromDictionary:[dictionary objectForKey:@"segmentSmoother"]];
        segments = [NSMutableArray arrayWithArray:[[dictionary objectForKey:@"segments"] jotMap:^id(id obj, NSUInteger index){
            NSString* className = [obj objectForKey:@"class"];
            Class class = NSClassFromString(className);
            return [[class alloc] initFromDictionary:obj];
        }]];
        texture = [[JotBrushTexture alloc] initFromDictionary:[dictionary objectForKey:@"texture"]];
    }
    return self;
}




@end
