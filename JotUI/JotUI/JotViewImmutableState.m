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

    }
    return self;
}



-(void) writeToDisk:(NSString*)plistPath{
    [stateDict setObject:[[stateDict objectForKey:@"stackOfStrokes"] jotMapWithSelector:@selector(asDictionary)] forKey:@"stackOfStrokes"];
    [stateDict setObject:[[stateDict objectForKey:@"stackOfUndoneStrokes"] jotMapWithSelector:@selector(asDictionary)] forKey:@"stackOfUndoneStrokes"];
    
    if(![stateDict writeToFile:plistPath atomically:YES]){
        NSLog(@"couldn't write plist file");
    }
}

@end
