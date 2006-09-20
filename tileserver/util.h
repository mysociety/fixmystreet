/*
 * util.h:
 * Utilities.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: util.h,v 1.1 2006-09-20 15:45:51 chris Exp $
 *
 */

#ifndef __UTIL_H_ /* include guard */
#define __UTIL_H_

/* err FORMAT [ARG ...]
 * Write an error message to standard error. */
    /* XXX format this with a timestamp for the error-log? */
#define err(...)    \
            do { \
                fprintf(stderr, "tileserver: "); \
                fprintf(stderr, __VA_ARGS__); \
                fprintf(stderr, "\n"); \
            } while (0)

/* die FORMAT [ARG ...]
 * Write an error message to standard error and exit unsuccessfully. */
#define die(...)    do { err(__VA_ARGS__); exit(1); } while (0)

/* util.c */
void *xmalloc(const size_t s);
void *xcalloc(const size_t a, const size_t b);
void *xrealloc(void *b, const size_t s);
char *xstrdup(const char *s);
void xfree(void *v);

#endif /* __UTIL_H_ */
