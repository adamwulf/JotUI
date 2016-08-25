//  This is Jeff LaMarche's GLProgram OpenGL shader wrapper class from his OpenGL ES 2.0 book.
//  A description of this can be found at his page on the topic:
//  http://iphonedevelopment.blogspot.com/2010/11/opengl-es-20-for-ios-chapter-4.html
//  I've extended this to be able to take programs as NSStrings in addition to files, for baked-in shaders

#import <Foundation/Foundation.h>

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <GLKit/GLKit.h>
#import "JotGLTypes.h"


@interface JotGLProgram : NSObject {
    NSMutableArray* _attributes;
    NSMutableArray* _uniforms;
    GLuint _programId;
    GLuint _vertShader;
    GLuint _fragShader;
}

@property(nonatomic, assign) GLSize canvasSize;
@property(readonly, copy, nonatomic) NSString* vertexShaderLog;
@property(readonly, copy, nonatomic) NSString* fragmentShaderLog;
@property(readonly, copy, nonatomic) NSString* programLog;
@property(nonatomic, readonly) NSArray<NSString*>* attributes;
@property(nonatomic, readonly) NSArray<NSString*>* uniforms;

- (id)initWithVertexShaderFilename:(NSString*)vShaderFilename
            fragmentShaderFilename:(NSString*)fShaderFilename
                    withAttributes:(NSArray<NSString*>*)attributes
                       andUniforms:(NSArray<NSString*>*)uniforms;

- (void)use;

- (GLuint)uniformMVPIndex;

@end
