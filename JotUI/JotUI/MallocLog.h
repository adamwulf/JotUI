//
//  MallocLog.h
//  JotUI
//
//  Created by Adam Wulf on 12/19/16.
//  Copyright © 2016 Milestone Made. All rights reserved.
//

#ifndef MallocLog_h
#define MallocLog_h

#include "stdlib.h"

static inline void* malloc_log(char const* file, int line, size_t size) {
    char* ret = (char*)malloc(size);

    NSLog(@"%s:%u malloc %ld at %p to %p", file, line, size, ret, ret + size);

    return ret;
}

static inline void* calloc_log(char const* file, int line, size_t size1, size_t size2) {
    char* ret = (char*)calloc(size1, size2);

    NSLog(@"%s:%u calloc %ld at %p to %p", file, line, size1 * size2, ret, ret + size1 * size2);

    return ret;
}

static inline void free_log(char const* file, int line, void* ptr) {
    NSLog(@"%s:%u free %p", file, line, ptr);
    free(ptr);
}

#define LOGMEMORY 1

#if LOGMEMORY

#ifdef DEBUG

#define mallocLog(__size__) malloc_log(__FILE__, __LINE__, __size__)
#define callocLog(__size1__, __size2__) calloc_log(__FILE__, __LINE__, __size1__, __size2__)
#define freeLog(__ptr__) free_log(__FILE__, __LINE__, __ptr__)

#else

#define mallocLog(__size__) malloc(__size__)
#define callocLog(__size1__, __size2__) calloc(__size1__, __size2__)
#define freeLog(__ptr__) free(__ptr__)

#endif

#endif

#endif /* MallocLog_h */
