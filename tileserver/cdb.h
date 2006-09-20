/*
 * cdb.h:
 * Interface to Dan-Bernstein-style CDB files.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: cdb.h,v 1.4 2006-09-20 14:24:10 chris Exp $
 *
 */

#ifndef __CDB_H_ /* include guard */
#define __CDB_H_

#include <sys/types.h>

#include <stdint.h>
#include <stdio.h>

typedef int cdb_result_t;
typedef uint32_t cdb_hash_t;

typedef struct cdb_datum {
    void *cd_buf;
    size_t cd_len;
} *cdb_datum;

typedef struct cdb *cdb;

/* error codes */
#define CDB_OUT_OF_MEMORY       -1
#define CDB_FILE_TOO_SMALL      -2
#define CDB_FILE_TOO_BIG        -3
#define CDB_FILE_TRUNCATED      -4
    /* one of the initial 256 pointers pointed outside the file */
#define CDB_BAD_HASHLOC_PTR     -5
    /* a datum pointer pointed outside the file or otherwise somewhere bogus */
#define CDB_BAD_RECORD_PTR      -6
    /* the record wasn't found */
#define CDB_NOT_FOUND           -7

#ifndef CDB_IMPL
extern
#endif /* CDB_IMPL */
    cdb_result_t cdb_errno;     /* XXX threads */

/* cdb.c */
cdb_hash_t cdb_hash(const unsigned char *buf, const size_t len);
cdb_hash_t cdb_hash_str(const char *s);
cdb_hash_t cdb_hash_datum(const cdb_datum d);
cdb cdb_open_fp(FILE *fp);
cdb cdb_open(const char *name);
void cdb_close(cdb C);
cdb_datum cdb_datum_alloc(const size_t len);
void cdb_datum_free(cdb_datum d);
cdb_datum cdb_get(cdb C, const cdb_datum key);
cdb_datum cdb_get_string(cdb C, const char *str);
cdb_datum cdb_get_buf(cdb C, const void *buf, const size_t len);
char *cdb_strerror(const cdb_result_t e);

#endif /* __CDB_H_ */
