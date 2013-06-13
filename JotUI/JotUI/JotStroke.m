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
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

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

-(void) mergeElementsIntoSingleVBO:(CGFloat)scale{
    
    NSDate *date = [NSDate date];

    int totalBytes = 0;
    int totalDots = 0;
    for(AbstractBezierPathElement* element in segments){
        totalBytes += [element numberOfBytes];
        totalDots += [element numberOfSteps];
    }
    
    if(totalBytes){
        
    }
    int loc = 0;
    void* vertexBuffer = malloc(totalBytes);
    AbstractBezierPathElement* prev = nil;
    for(AbstractBezierPathElement* element in segments){
        if([element numberOfBytes]){
            struct Vertex* data = [element generatedVertexArrayWithPreviousElement:prev forScale:scale];
            prev = element;
            memcpy(vertexBuffer + loc, data, [element numberOfBytes]);
            loc += [element numberOfBytes];
        }
    }
    
    GLuint vbo,vao;
    glGenVertexArraysOES(1, &vao);
    glBindVertexArrayOES(vao);
    glGenBuffers(1,&vbo);
    glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER, totalBytes, vertexBuffer, GL_STATIC_DRAW);
    glVertexPointer(2, GL_FLOAT, sizeof(struct Vertex), offsetof(struct Vertex, Position));
    glColorPointer(4, GL_FLOAT, sizeof(struct Vertex), offsetof(struct Vertex, Color));
    glTexCoordPointer(2, GL_SHORT, sizeof(struct Vertex), offsetof(struct Vertex, Texture));
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glBindBuffer(GL_ARRAY_BUFFER,0);
    glBindVertexArrayOES(0);

    NSLog(@"total dots: %d in total bytes: %d  in %d elements in %f", totalDots, totalBytes, [segments count], [date timeIntervalSinceNow]);

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
