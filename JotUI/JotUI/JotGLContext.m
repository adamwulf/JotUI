//
//  JotGLContext.m
//  JotUI
//
//  Created by Adam Wulf on 9/15/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLContext.h"

@implementation JotGLContext

- (id) initWithAPI:(EAGLRenderingAPI) api{
    if(self = [super initWithAPI:api]){
        // noop
        
    }
    return self;
}


- (id) initWithAPI:(EAGLRenderingAPI) api sharegroup:(EAGLSharegroup*) sharegroup{
    if(self = [super initWithAPI:api sharegroup:sharegroup]){
        // noop
    }
    return self;
}


+(BOOL) setCurrentContext:(EAGLContext *)context{
    EAGLContext* curr = [EAGLContext currentContext];
    if(curr != context){
        glFlush();
        return [EAGLContext setCurrentContext:context];
    }
    return YES;
}

@end
