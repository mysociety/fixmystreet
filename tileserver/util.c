/*
 * util.c:
 * Miscellaneous utility functions.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 */

static const char rcsid[] = "$Id: util.c,v 1.1 2006-09-20 15:45:51 chris Exp $";

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "util.h"

/*
 * Wrappers for memory-allocation functions.
 */
void *xmalloc(const size_t s) {
    void *v;
    if (!(v = malloc(s)))
        die("malloc(%u bytes): %s", (unsigned)s, strerror(errno));
    return v;
}

void *xcalloc(const size_t a, const size_t b) {
    void *v;
    if (!(v = calloc(a, b)))
        die("calloc(%u * %u bytes): %s",
                (unsigned)a, (unsigned)b, strerror(errno));
    return v;
}

void *xrealloc(void *b, const size_t s) {
    void *v;
    if (!(v = realloc(b, s)))
        die("realloc(%u bytes): %s", (unsigned)s, strerror(errno));
    return v;
}

char *xstrdup(const char *s) {
    char *t;
    if (!(t = strdup(s)))
        die("strdup(%u bytes): %s", (unsigned)(strlen(s) + 1), strerror(errno));
    return t;
}

void xfree(void *v) {
    if (v) free(v);
}
