//
//  JotViewImmutableState.m
//  JotUI
//
//  Created by Adam Wulf on 6/22/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotViewImmutableState.h"
#import "JotStroke.h"
#import "JotImmutableStroke.h"
#import "NSArray+JotMapReduce.h"

@implementation JotViewImmutableState{
    NSMutableDictionary* stateDict;
}

/**
 * this immutable state is initialized from within
 * the JotViewState. This method is only available
 * from within the JotViewState class.
 */
-(id) initWithDictionary:(NSDictionary*)stateInfo{
    if(self = [super init]){
        stateDict = [NSMutableDictionary dictionary];
        
        NSMutableArray* stackOfImmutableStrokes = [NSMutableArray array];
        NSMutableArray* stackOfImmutableUndoneStrokes = [NSMutableArray array];
        for(JotStroke* stroke in [stateInfo objectForKey:@"stackOfStrokes"]){
            [stackOfImmutableStrokes addObject:[[JotImmutableStroke alloc] initWithJotStroke:stroke]];
        }
        for(JotStroke* stroke in [stateInfo objectForKey:@"stackOfUndoneStrokes"]){
            [stackOfImmutableUndoneStrokes addObject:[[JotImmutableStroke alloc] initWithJotStroke:stroke]];
        }
        
        [stateDict setObject:stackOfImmutableStrokes forKey:@"stackOfStrokes"];
        [stateDict setObject:stackOfImmutableUndoneStrokes forKey:@"stackOfUndoneStrokes"];
        [stateDict setObject:[stateInfo objectForKey:@"undoHash"] forKey:@"undoHash"];

    }
    return self;
}


/**
 * this will write out the state to the specified path.
 * this file can be loaded into a JotViewState object
 */
-(void) writeToDisk:(NSString*)plistPath{
    if(![[stateDict objectForKey:@"hasConverted"] boolValue]){
        // only convert the state one time when needed. otherwise
        // skip this step and write straight to disk
        [stateDict setObject:[[stateDict objectForKey:@"stackOfStrokes"] jotMapWithSelector:@selector(asDictionary)] forKey:@"stackOfStrokes"];
        [stateDict setObject:[[stateDict objectForKey:@"stackOfUndoneStrokes"] jotMapWithSelector:@selector(asDictionary)] forKey:@"stackOfUndoneStrokes"];
        [stateDict setObject:[NSNumber numberWithBool:YES] forKey:@"hasConverted"];
    }
    
    if(![stateDict writeToFile:plistPath atomically:YES]){
        NSLog(@"couldn't write plist file");
    }else{
        NSLog(@"wrote to disk: %u", [self undoHash]);
    }
}

/**
 * This hash isn't calculated here, because the objects in the
 * stackOfStrokes array are JotImmutableStrokes instead of
 * JotStrokes, so their hash value will be different, which
 * causes the calculated hash to be different.
 *
 * instead, we import the hash value from the state dictionary.
 */
-(NSUInteger) undoHash{
    NSUInteger hashVal = [[stateDict objectForKey:@"undoHash"] unsignedIntegerValue];
    return hashVal;
}

@end
