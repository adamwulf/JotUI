//
//  JotGLTextureBackedFrameBuffer.m
//  JotUI
//
//  Created by Adam Wulf on 6/5/13.
//  Copyright (c) 2013 Adonit. All rights reserved.
//

#import "JotGLTextureBackedFrameBuffer.h"
#import "JotUI.h"
#import <OpenGLES/EAGL.h>
#import "ShaderHelper.h"
#import "JotGLLayerBackedFrameBuffer.h"
#import "JotGLTextureBackedFrameBuffer+Private.h"

tex_programInfo_t quad_program[NUM_PROGRAMS] = {
    { "quad.vsh",   "quad.fsh" },     // PROGRAM_QUAD
};

dispatch_queue_t importExportTextureQueue;

/**
 * this frame buffer will use a texture as it's backing store,
 * so that anything drawn to this frame buffer will show up
 * on the texture that its initialized with.
 *
 * one very important thing is to rebind the texture after it
 * has been drawn to with this frame buffer
 *
 * it's also very important to call [context flush] after drawing
 * using this framebuffer, and to rebind the backing texture before
 * drawing with it
 */
@implementation JotGLTextureBackedFrameBuffer{
    __strong JotGLTexture* texture;

    BOOL hasEverSetup;
}

@synthesize texture;

-(id) initForTexture:(JotGLTexture*)_texture{
    if(self = [super init]){
        [JotGLContext runBlock:^(JotGLContext* context){
            texture = _texture;
            framebufferID = [context generateFramebufferWithTextureBacking:texture];
        }];
    }
    return self;
}

-(void) bind{
    glActiveTexture(GL_TEXTURE0);
    printOpenGLError();

    [texture bind];
    [super bind];

    [self setupShaders];

    glUseProgram(quad_program[PROGRAM_QUAD].id);
    printOpenGLError();
    glBindTexture(GL_TEXTURE_2D, self.texture.textureID);
    printOpenGLError();
    glDisable(GL_CULL_FACE);
    printOpenGLError();
    glUniform1i(uniforms[UNIFORM_VIDEOFRAME], 0);
    printOpenGLError();

}

-(void) unbind{
    [super unbind];
    [texture unbind];
}

#pragma mark - Dispatch Queues

+(dispatch_queue_t) importExportTextureQueue{
    if(!importExportTextureQueue){
        importExportTextureQueue = dispatch_queue_create("com.milestonemade.looseleaf.importExportTextureQueue", DISPATCH_QUEUE_SERIAL);
    }
    return importExportTextureQueue;
}

-(void) clear{
    JotGLContext* subContext = [[JotGLContext alloc] initWithName:@"JotTextureBackedFBOSubContext" andSharegroup:[JotGLContext currentContext].sharegroup andValidateThreadWith:^BOOL{
        return [JotView isImportExportImageQueue];
    }];
    [subContext runBlock:^{
        // render it to the backing texture
        //
        //
        // something below here is wrong.
        // and/or how this interacts later
        // with other threads
        [texture bind];
        [subContext bindFramebuffer:framebufferID];
        [subContext clear];
        
        [subContext unbindFramebuffer];
        [texture unbind];
    }];
}

-(void) deleteAssets{
    if(framebufferID && ![JotGLContext currentContext]){
        DebugLog(@"nope");
    }
    if(framebufferID){
        [JotGLContext runBlock:^(JotGLContext *context) {
            [context deleteFramebuffer:framebufferID];
        }];
        framebufferID = 0;
    }
}

-(void) dealloc{
    NSAssert([JotGLContext currentContext] != nil, @"must be on glcontext");
    [self deleteAssets];
}



- (void)setupShaders
{
    if(!hasEverSetup){
        hasEverSetup = YES;

        for (int i = 0; i < NUM_TEX_PROGRAMS; i++)
        {
            // Set constant/initalize uniforms
            if (i == PROGRAM_QUAD)
            {
                char *vsrc = readFile(pathForResource(quad_program[i].vert));
                char *fsrc = readFile(pathForResource(quad_program[i].frag));
                GLsizei attribCt = 0;
                GLchar *attribUsed[NUM_TEX_ATTRIBUTES];
                GLint attrib[NUM_TEX_ATTRIBUTES];
                GLchar *attribName[NUM_TEX_ATTRIBUTES] = {
                    "position", "inputTextureCoordinate"
                };
                const GLchar *uniformName[NUM_TEX_UNIFORMS] = {
                    "videoFrame",
                };

                // auto-assign known attribs
                for (int j = 0; j < NUM_TEX_ATTRIBUTES; j++)
                {
                    if (strstr(vsrc, attribName[j]))
                    {
                        attrib[attribCt] = j;
                        attribUsed[attribCt++] = attribName[j];
                    }
                }

                GLint status = glueCreateProgram(vsrc, fsrc,
                                                 attribCt, (const GLchar **)&attribUsed[0], attrib,
                                                 NUM_TEX_UNIFORMS, &uniformName[0], quad_program[i].uniform,
                                                 &quad_program[i].id);

                NSLog(@"quad program: %d => %d %d", status, quad_program[0].id, quad_program[0].uniform[0]);

                free(vsrc);
                free(fsrc);

                glUseProgram(quad_program[PROGRAM_QUAD].id);
                printOpenGLError();

                // our texture will be bound to texture 0
                glUniform1i(quad_program[PROGRAM_QUAD].uniform[UNIFORM_VIDEOFRAME], 0);
                printOpenGLError();
            }
        }
        
        glError();
    }
}

@end
