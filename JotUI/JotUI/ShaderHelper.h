//
//  ShaderHelper.h
//  JotUI
//
//  Created by Adam Wulf on 1/2/16.
//  Copyright © 2016 Adonit. All rights reserved.
//
#ifndef ShaderHelper_h
#define ShaderHelper_h

#import <GLKit/GLKit.h>
#import "shaderUtil.h"
#import "fileUtil.h"
#import "debug.h"


//CONSTANTS:

#define kBrushOpacity		(1.0 / 3.0)
#define kBrushPixelStep		3
#define kBrushScale			2

// Attribute index.
enum {
    ATTRIB_TEX_VERTEX,
    ATTRIB_TEX_TEXTUREPOSITON,
    NUM_TEX_ATTRIBUTES
};


// Shaders
enum {
    PROGRAM_POINT,
    NUM_PROGRAMS
};

// Shaders
enum {
    PROGRAM_QUAD,
    NUM_TEX_PROGRAMS
};

enum {
    UNIFORM_MVP,
    UNIFORM_POINT_SIZE,
    UNIFORM_VERTEX_COLOR,
    UNIFORM_TEXTURE,
    NUM_UNIFORMS
};

enum {
    ATTRIB_VERTEX,
    NUM_ATTRIBS
};

// Uniform index.
enum {
    UNIFORM_VIDEOFRAME,
    NUM_TEX_UNIFORMS
};
GLint uniforms[NUM_TEX_UNIFORMS];

typedef struct {
    char *vert, *frag;
    GLint uniform[NUM_TEX_UNIFORMS];
    GLuint id;
} tex_programInfo_t;

typedef struct {
    char *vert, *frag;
    GLint uniform[NUM_UNIFORMS];
    GLuint id;
} programInfo_t;

// Texture
typedef struct {
    GLuint id;
    GLsizei width, height;
} textureInfo_t;


#endif /* ShaderHelper_h */
