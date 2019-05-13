//
//  JotImmutableStroke.m
//  JotUI
//
//  Created by Adam Wulf on 6/22/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import "JotImmutableStroke.h"


@implementation JotImmutableStroke {
    SegmentSmoother* segmentSmoother;
    // this will store all the segments in drawn order
    NSArray* segments;
    // this is the texture to use when drawing the stroke
    JotBrushTexture* texture;
    NSString* uuid;
    //
    NSString* strokeClassName;
}

- (id)initWithJotStroke:(JotStroke*)stroke {
    if (self = [super init]) {
        segmentSmoother = stroke.segmentSmoother;
        segments = [NSArray arrayWithArray:stroke.segments];
        texture = stroke.texture;
        uuid = [stroke uuid];
        strokeClassName = NSStringFromClass([stroke class]);
    }
    return self;
}

- (NSMutableArray*)segments {
    return [NSMutableArray arrayWithArray:segments];
}

- (SegmentSmoother*)segmentSmoother {
    return segmentSmoother;
}

- (JotBrushTexture*)texture {
    return texture;
}

- (NSString*)uuid {
    return uuid;
}

- (NSDictionary*)asDictionary {
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:[super asDictionary]];
    [dict setObject:strokeClassName forKey:@"class"];
    return dict;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    segmentSmoother = [decoder decodeObjectForKey:@"segmentSmoother"];
    segments = [decoder decodeObjectForKey:@"segments"];
    texture = [decoder decodeObjectForKey:@"texture"];
    uuid = [decoder decodeObjectForKey:@"uuid"];
    strokeClassName = [decoder decodeObjectForKey:@"strokeClassName"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:segmentSmoother forKey:@"segmentSmoother"];
    [encoder encodeObject:texture forKey:@"texture"];
    [encoder encodeObject:uuid forKey:@"uuid"];
    [encoder encodeObject:strokeClassName forKey:@"strokeClassName"];
    [encoder encodeObject:segments forKey:@"segments"];
}

@end
