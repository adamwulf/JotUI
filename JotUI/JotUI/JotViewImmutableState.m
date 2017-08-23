//
//  JotViewImmutableState.m
//  JotUI
//
//  Created by Adam Wulf on 6/22/13.
//  Copyright (c) 2013 Milestone Made. All rights reserved.
//

#import "JotViewImmutableState.h"
#import "JotStroke.h"
#import "JotImmutableStroke.h"
#import "JotViewState.h"
#import "NSArray+JotMapReduce.h"


@implementation JotViewImmutableState {
    NSMutableDictionary* stateDict;
}

/**
 * this immutable state is initialized from within
 * the JotViewState. This method is only available
 * from within the JotViewState class.
 */
- (id)initWithDictionary:(NSDictionary*)stateInfo {
    if (self = [super init]) {
        stateDict = [NSMutableDictionary dictionary];

        NSMutableArray* stackOfImmutableStrokes = [NSMutableArray array];
        NSMutableArray* stackOfImmutableUndoneStrokes = [NSMutableArray array];
        for (JotStroke* stroke in [stateInfo objectForKey:@"stackOfStrokes"]) {
            [stackOfImmutableStrokes addObject:[[JotImmutableStroke alloc] initWithJotStroke:stroke]];
        }
        for (JotStroke* stroke in [stateInfo objectForKey:@"stackOfUndoneStrokes"]) {
            [stackOfImmutableUndoneStrokes addObject:[[JotImmutableStroke alloc] initWithJotStroke:stroke]];
        }

        [stateDict setObject:stackOfImmutableStrokes forKey:@"stackOfStrokes"];
        [stateDict setObject:stackOfImmutableUndoneStrokes forKey:@"stackOfUndoneStrokes"];
        [stateDict setObject:[stateInfo objectForKey:@"undoHash"] forKey:@"undoHash"];
        [stateDict setObject:[stateInfo objectForKey:@"undoLimit"] forKey:@"undoLimit"];

        [stateDict setObject:[stateInfo objectForKey:@"screenSize.width"] forKey:@"screenSize.width"];
        [stateDict setObject:[stateInfo objectForKey:@"screenSize.height"] forKey:@"screenSize.height"];
    }
    return self;
}

/**
 * this will write out the state to the specified path.
 * this file can be loaded into a JotViewState object
 */
- (void)writeToDisk:(NSString*)plistPath {
    if (![JotView isImportExportStateQueue]) {
        @throw [NSException exceptionWithName:@"InconsistentQueueException" reason:@"writing immutable jotViewState in wrong queue" userInfo:nil];
    }
    if (![[stateDict objectForKey:@"hasConverted"] boolValue]) {
        // write each stroke to disk to its own file. this is because the
        // vertex buffer for each stroke can be fairly large. writing it
        // out will let us write each stroke once instead of every time the
        // state is saved
        NSString* stateDirectory = [plistPath stringByDeletingLastPathComponent];
        NSMutableArray* fileNamesOfStrokes = [NSMutableArray array];
        [[[stateDict objectForKey:@"stackOfStrokes"] arrayByAddingObjectsFromArray:[stateDict objectForKey:@"stackOfUndoneStrokes"]] jotMap:^id(id obj, NSUInteger index) {
            NSString* filename = [[stateDirectory stringByAppendingPathComponent:[obj uuid]] stringByAppendingPathExtension:kJotStrokeFileExt];
            NSFileManager* manager = [NSFileManager defaultManager];
            if (![manager fileExistsAtPath:filename] || self.mustOverwriteAllStrokeFiles) {
                [[obj asDictionary] writeToFile:filename atomically:YES];
            }
            [fileNamesOfStrokes addObject:filename];
            return obj;
        }];

        // now that we've saved all of our strokes,
        // we need to delete the files of any strokes that were
        // written to the disk and aren't in our state dictionary any more.
        // to do that, loop over the directory and compare to the files we just wrote.
        NSArray* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:stateDirectory error:nil];
        for (NSString* item in contents) {
            NSString* fileInDir = [stateDirectory stringByAppendingPathComponent:item];
            if (![fileNamesOfStrokes containsObject:fileInDir] && [[fileInDir pathExtension] isEqualToString:kJotStrokeFileExt]) {
                [[NSFileManager defaultManager] removeItemAtPath:fileInDir error:nil];
            }
        }

        [stateDict setObject:[[stateDict objectForKey:@"stackOfStrokes"] jotMapWithSelector:@selector(uuid)] forKey:@"stackOfStrokes"];
        [stateDict setObject:[[stateDict objectForKey:@"stackOfUndoneStrokes"] jotMapWithSelector:@selector(uuid)] forKey:@"stackOfUndoneStrokes"];
        [stateDict setObject:[NSNumber numberWithBool:YES] forKey:@"hasConverted"];
    }

    if (![stateDict writeToFile:plistPath atomically:YES]) {
        DebugLog(@"couldn't write plist file");
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
- (NSUInteger)undoHash {
    return [[stateDict objectForKey:@"undoHash"] unsignedIntegerValue];
}

@end
