//
//  JotGLRenderBackedFrameBuffer.m
//  JotUI
//
//  Created by Adam Wulf on 1/29/15.
//  Copyright (c) 2015 Adonit. All rights reserved.
//

#import "JotGLLayerBackedFrameBuffer.h"
#import "JotView.h"
#import "ShaderHelper.h"

programInfo_t program[NUM_PROGRAMS] = {
    { "point.vsh",   "point.fsh" },     // PROGRAM_POINT
};


@implementation JotGLLayerBackedFrameBuffer{
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    GLuint viewRenderbuffer;
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    GLuint depthRenderbuffer;

    CGSize initialViewport;
    
    CALayer<EAGLDrawable>* layer;
    
    // YES if we need to present our renderbuffer on the
    // next display link
    BOOL needsPresentRenderBuffer;
    // YES if we should limit to 30fps, NO otherwise
    BOOL shouldslow;
    // helper var to toggle between frames for 30fps limit
    BOOL slowtoggle;


    // TODO: pull this into somewhere else
    textureInfo_t brushTexture;     // brush texture
    GLfloat brushColor[4];          // brush color
}

@synthesize initialViewport;
@synthesize shouldslow;

-(id) initForLayer:(CALayer<EAGLDrawable>*)_layer{
    if(self = [super init]){
        CheckMainThread;
        layer = _layer;
        [JotGLContext runBlock:^(JotGLContext* context){
            
            GLSize backingSize = [context generateFramebuffer:&framebufferID andRenderbuffer:&viewRenderbuffer andDepthRenderBuffer:&depthRenderbuffer forLayer:layer];

            CGRect frame = layer.bounds;
            CGFloat scale = layer.contentsScale;
            
            initialViewport = CGSizeMake(frame.size.width * scale, frame.size.height * scale);
            
            [context glViewportWithX:0 y:0 width:(GLsizei)initialViewport.width height:(GLsizei)initialViewport.height];
            
            [context assertCheckFramebuffer];
            
            [context bindRenderbuffer:viewRenderbuffer];
            
            // Load the brush texture
            brushTexture = [JotGLLayerBackedFrameBuffer textureFromName:@"Particle.png"];

            brushColor[0] = 0 * kBrushOpacity;
            brushColor[1] = 0 * kBrushOpacity;
            brushColor[2] = 1.0 * kBrushOpacity;
            brushColor[3] = kBrushOpacity;

            // Load shaders
            [self setupShadersWithSize:backingSize];

            [self clear];
        }];
    }
    return self;
}

-(void) bind{
    [super bind];
    [JotGLContext runBlock:^(JotGLContext * context) {
        [context bindRenderbuffer:viewRenderbuffer];

        glUseProgram(program[PROGRAM_POINT].id);
        glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
    }];
}

-(void) unbind{
    [super unbind];
    [JotGLContext runBlock:^(JotGLContext * context) {
        [context unbindRenderbuffer];
    }];
}

-(void) setNeedsPresentRenderBuffer{
    needsPresentRenderBuffer = YES;
}

-(void) presentRenderBufferInContext:(JotGLContext*)context{
    [context runBlock:^{
        if(needsPresentRenderBuffer && (!shouldslow || slowtoggle)){
            [self bind];
            //        NSLog(@"presenting");
            [context assertCurrentBoundFramebufferIs:framebufferID andRenderBufferIs:viewRenderbuffer];
            [context assertCheckFramebuffer];

            [context presentRenderbuffer];

            needsPresentRenderBuffer = NO;
            [self unbind];
        }
        slowtoggle = !slowtoggle;
        if([context needsFlush]){
            [context flush];
        }
    }];
}

-(void) clear{
    [JotGLContext runBlock:^(JotGLContext*context){
        [self bind];
        //
        // something below here is wrong.
        // and/or how this interacts later
        // with other threads (?)
        [context clear];
        
        [self unbind];
    }];
}

-(void) deleteAssets{
    [JotGLContext runBlock:^(JotGLContext * context) {
        if(framebufferID){
            [context deleteFramebuffer:framebufferID];
            framebufferID = 0;
        }
        if(viewRenderbuffer){
            [context deleteRenderbuffer:viewRenderbuffer];
            viewRenderbuffer = 0;
        }
        if(depthRenderbuffer){
            [context deleteRenderbuffer:depthRenderbuffer];
            depthRenderbuffer = 0;
        }
    }];
}

-(void) dealloc{
    NSAssert([JotGLContext currentContext] != nil, @"must be on glcontext");
    [self deleteAssets];
}





// Create a texture from an image
+ (textureInfo_t)textureFromName:(NSString *)name
{
    CGImageRef		brushImage;
    CGContextRef	brushContext;
    GLubyte			*brushData;
    size_t			width, height;
    GLuint          texId;
    textureInfo_t   texture;

    // First create a UIImage object from the data in a image file, and then extract the Core Graphics image
    brushImage = [UIImage imageNamed:name].CGImage;

    // Get the width and height of the image
    width = CGImageGetWidth(brushImage);
    height = CGImageGetHeight(brushImage);

    // Make sure the image exists
    if(brushImage) {
        // Allocate  memory needed for the bitmap context
        brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
        // Use  the bitmatp creation function provided by the Core Graphics framework.
        brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
        // After you create the context, you can draw the  image to the context.
        CGContextDrawImage(brushContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), brushImage);
        // You don't need the context at this point, so you need to release it to avoid memory leaks.
        CGContextRelease(brushContext);
        // Use OpenGL ES to generate a name for the texture.
        glGenTextures(1, &texId);
        // Bind the texture name.
        glBindTexture(GL_TEXTURE_2D, texId);
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // Specify a 2D texture image, providing the a pointer to the image data in memory
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
        // Release  the image data; it's no longer needed
        free(brushData);

        texture.id = texId;
        texture.width = (int)width;
        texture.height = (int)height;
    }

    return texture;
}

- (void)setupShadersWithSize:(GLSize)backingSize
{
    brushTexture = [JotGLLayerBackedFrameBuffer textureFromName:@"Particle.png"];

    for (int i = 0; i < NUM_PROGRAMS; i++)
    {
        char *vsrc = readFile(pathForResource(program[i].vert));
        char *fsrc = readFile(pathForResource(program[i].frag));
        GLsizei attribCt = 0;
        GLchar *attribUsed[NUM_ATTRIBS];
        GLint attrib[NUM_ATTRIBS];
        GLchar *attribName[NUM_ATTRIBS] = {
            "inVertex",
        };
        const GLchar *uniformName[NUM_UNIFORMS] = {
            "MVP", "pointSize", "vertexColor", "texture",
        };

        // auto-assign known attribs
        for (int j = 0; j < NUM_ATTRIBS; j++)
        {
            if (strstr(vsrc, attribName[j]))
            {
                attrib[attribCt] = j;
                attribUsed[attribCt++] = attribName[j];
            }
        }

        glueCreateProgram(vsrc, fsrc,
                          attribCt, (const GLchar **)&attribUsed[0], attrib,
                          NUM_UNIFORMS, &uniformName[0], program[i].uniform,
                          &program[i].id);
        free(vsrc);
        free(fsrc);

        // Set constant/initalize uniforms
        if (i == PROGRAM_POINT)
        {
            glUseProgram(program[PROGRAM_POINT].id);

            // the brush texture will be bound to texture unit 0
            glUniform1i(program[PROGRAM_POINT].uniform[UNIFORM_TEXTURE], 0);

            // viewing matrices
            GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingSize.width, 0, backingSize.height, -1, 1);
            GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
            GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);

            glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);

            // point size
            glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_POINT_SIZE], brushTexture.width / kBrushScale);
            
            // initialize brush color
            glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
        }
    }
    
    glError();
}

@end
