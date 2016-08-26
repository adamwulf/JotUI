//
//  JotGLTypes.h
//  JotUI
//
//  Created by Adam Wulf on 2/26/15.
//  Copyright (c) 2015 Milestone Made. All rights reserved.
//

#ifndef JotUI_JotGLTypes_h
#define JotUI_JotGLTypes_h

struct GLSize {
    GLuint width;
    GLuint height;
};
typedef struct GLSize GLSize;

CG_INLINE GLSize
GLSizeMake(GLuint width, GLuint height) {
    GLSize size;
    size.width = width;
    size.height = height;
    return size;
}

CG_INLINE GLSize
GLSizeFromCGSize(CGSize cgSize) {
    GLSize size;
    size.width = ceilf(cgSize.width);
    size.height = ceilf(cgSize.height);
    return size;
}

#endif
