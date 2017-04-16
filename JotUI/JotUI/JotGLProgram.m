//  This is based on Jeff LaMarche's GLProgram OpenGL shader wrapper class from his OpenGL ES 2.0 book.
//  A description of this can be found at his page on the topic:
//  http://iphonedevelopment.blogspot.com/2010/11/opengl-es-20-for-ios-chapter-4.html


#import "JotGLProgram.h"
#import <GLKit/GLKit.h>
#import "JotGLContext.h"

#pragma mark Function Pointer Definitions
typedef void (*GLInfoFunction)(GLuint program, GLenum pname, GLint* params);
typedef void (*GLLogFunction)(GLuint program, GLsizei bufsize, GLsizei* length, GLchar* infolog);

#pragma mark -
#pragma mark Private Extension Method Declaration


@interface JotGLProgram ()

- (BOOL)compileShader:(GLuint*)shader
                 type:(GLenum)type
               string:(NSString*)shaderString;
@end

#pragma mark -

static NSMutableArray* _jotGLProgramAttributes;


@implementation JotGLProgram


- (id)initWithVertexShaderFilename:(NSString*)vShaderFilename
            fragmentShaderFilename:(NSString*)fShaderFilename
                    withAttributes:(NSArray<NSString*>*)attributes
                       andUniforms:(NSArray<NSString*>*)uniforms {
    NSString* vertShaderPathname = [[NSBundle mainBundle] pathForResource:vShaderFilename ofType:@"vsh"];
    NSString* vShaderString = [NSString stringWithContentsOfFile:vertShaderPathname encoding:NSUTF8StringEncoding error:nil];
    NSURL* frameworkURL = [[NSBundle mainBundle] URLForResource:@"JotUI" withExtension:@"framework" subdirectory:@"Frameworks"];

    if (!vShaderString) {
        vertShaderPathname = [[NSBundle bundleWithURL:frameworkURL] pathForResource:vShaderFilename ofType:@"vsh"];
        vShaderString = [NSString stringWithContentsOfFile:vertShaderPathname encoding:NSUTF8StringEncoding error:nil];
    }

    NSString* fragShaderPathname = [[NSBundle mainBundle] pathForResource:fShaderFilename ofType:@"fsh"];
    NSString* fShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];

    if (!fShaderString) {
        fragShaderPathname = [[NSBundle bundleWithURL:frameworkURL] pathForResource:fShaderFilename ofType:@"fsh"];
        fShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];
    }

    if ((self = [super init])) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _jotGLProgramAttributes = [NSMutableArray array];
        });

        _attributes = [NSMutableArray array];
        _programId = glCreateProgram();
        _uniforms = [NSMutableArray array];

        if (![self compileShader:&_vertShader
                            type:GL_VERTEX_SHADER
                          string:vShaderString]) {
            NSLog(@"Failed to compile vertex shader");
            @throw [NSException exceptionWithName:@"JotGLProgramException" reason:@"Failed to compile vertex shader" userInfo:@{ @"log": _vertexShaderLog }];
        }

        // Create and compile fragment shader
        if (![self compileShader:&_fragShader
                            type:GL_FRAGMENT_SHADER
                          string:fShaderString]) {
            NSLog(@"Failed to compile fragment shader");
            @throw [NSException exceptionWithName:@"JotGLProgramException" reason:@"Failed to compile fragment shader" userInfo:@{ @"log": _fragmentShaderLog }];
        }

        glAttachShader(_programId, _vertShader);
        glAttachShader(_programId, _fragShader);

        for (NSString* attr in attributes) {
            [self addAttribute:attr];
        }

        [_uniforms addObjectsFromArray:uniforms];

        if (![self link]) {
            @throw [NSException exceptionWithName:@"JotGLProgramException" reason:@"Failed to link program" userInfo:nil];
        }

        [self validate];
    }

    return self;
}

#pragma mark - Step 1: Compile

- (BOOL)compileShader:(GLuint*)shader
                 type:(GLenum)type
               string:(NSString*)shaderString {
    GLint status;
    const GLchar* source;

    source =
        (GLchar*)[shaderString UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }

    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);

    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);

    if (status != GL_TRUE) {
        GLint logLength;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar* log = (GLchar*)malloc(logLength);
            glGetShaderInfoLog(*shader, logLength, &logLength, log);
            if (shader == &_vertShader) {
                _vertexShaderLog = [NSString stringWithFormat:@"%s", log];
            } else {
                _fragmentShaderLog = [NSString stringWithFormat:@"%s", log];
            }

            free(log);
        }
    }

    return status == GL_TRUE;
}

#pragma mark - Attributes and Uniforms

+ (GLuint)attributeIndex:(NSString*)attributeName {
    if ([_jotGLProgramAttributes containsObject:attributeName]) {
        return (GLuint)[_jotGLProgramAttributes indexOfObject:attributeName];
    } else {
        @throw [NSException exceptionWithName:@"GLProgramException" reason:[NSString stringWithFormat:@"Program does not contain a attribute '%@'", attributeName] userInfo:nil];
    }
}

- (GLuint)uniformIndex:(NSString*)uniformName {
    if ([_uniforms containsObject:uniformName]) {
        return glGetUniformLocation(_programId, [uniformName UTF8String]);
    } else {
        @throw [NSException exceptionWithName:@"GLProgramException" reason:[NSString stringWithFormat:@"Program does not contain a uniform '%@'", uniformName] userInfo:nil];
    }
}

#pragma mark - Public

- (void)use {
    glUseProgram(_programId);

    [self enableAndDisableAllAttributes];

    if (!self.canvasSize.width) {
        @throw [NSException exceptionWithName:@"JotGLProgramException" reason:@"Attempting to use program without a canvas size" userInfo:nil];
    }
    if (!self.canvasSize.height) {
        @throw [NSException exceptionWithName:@"JotGLProgramException" reason:@"Attempting to use program without a canvas size" userInfo:nil];
    }

    // viewing matrices
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, self.canvasSize.width, 0, self.canvasSize.height, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
    GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);

    glUniformMatrix4fv([self uniformMVPIndex], 1, GL_FALSE, MVPMatrix.m);
}

- (GLuint)uniformMVPIndex {
    return [self uniformIndex:@"MVP"];
}

#pragma mark - Private

- (BOOL)link {
    GLint status;

    glLinkProgram(_programId);

    glGetProgramiv(_programId, GL_LINK_STATUS, &status);
    if (status == GL_FALSE)
        return NO;

    if (_vertShader) {
        glDeleteShader(_vertShader);
        _vertShader = 0;
    }
    if (_fragShader) {
        glDeleteShader(_fragShader);
        _fragShader = 0;
    }

    return YES;
}

- (void)validate;
{
    GLint logLength;

    glValidateProgram(_programId);
    glGetProgramiv(_programId, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar* log = (GLchar*)malloc(logLength);
        glGetProgramInfoLog(_programId, logLength, &logLength, log);
        _programLog = [NSString stringWithFormat:@"%s", log];
        free(log);
    }
    if ([_programLog length]) {
        NSLog(@"Program Log: %@", _programLog);
    }
}

- (void)addAttribute:(NSString*)attributeName {
    if (![_jotGLProgramAttributes containsObject:attributeName]) {
        [_jotGLProgramAttributes addObject:attributeName];
    }
    if (![_attributes containsObject:attributeName]) {
        [_attributes addObject:attributeName];
    }

    glBindAttribLocation(_programId,
                         (GLuint)[_jotGLProgramAttributes indexOfObject:attributeName],
                         [attributeName UTF8String]);
}

- (void)enableAndDisableAllAttributes {
    for (NSString* attr in _jotGLProgramAttributes) {
        if ([_attributes containsObject:attr]) {
            glEnableVertexAttribArray([JotGLProgram attributeIndex:attr]);
        } else {
            glDisableVertexAttribArray([JotGLProgram attributeIndex:attr]);
        }
    }
}

#pragma mark -

- (void)dealloc {
    [JotGLContext runBlock:^(JotGLContext* context) {
        if (_vertShader) {
            glDeleteShader(_vertShader);
        }

        if (_fragShader) {
            glDeleteShader(_fragShader);
        }

        if (_programId) {
            glDeleteProgram(_programId);
        }
    }];
}

@end
