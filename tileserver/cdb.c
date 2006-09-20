/*
 * cdb.c:
 * Read data from Dan-Bernstein-style CDB files.
 *
 * See: http://cr.yp.to/cdb/cdb.txt
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 */

static const char rcsid[] = "$Id: cdb.c,v 1.4 2006-09-20 14:24:10 chris Exp $";

#include <sys/types.h>

#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/stat.h>

#define CDB_IMPL
#include "cdb.h"

#ifdef VERBOSE_DEBUGGING
#   define debug(...)  \
        do { \
            fprintf(stderr, __VA_ARGS__); \
                fprintf(stderr, "\n"); \
        } while (0)
#else
#   define debug(...)  do { } while (0)
#endif /* VERBOSE_DEBUGGING */

/* struct cdb
 * Internals of CDB object. */
struct cdb {
    FILE *c_fp;
    struct stat c_st;
    bool c_close_on_destroy;
    struct {
        uint32_t off, len;
    } c_hashlocs[256];
};

/* Length of the initial portion of the file which gives the hash table
 * locations. */
#define HASHPTR_LEN     (256 * 8)

static size_t do_fread(FILE *fp, void *buf, const size_t len) {
    return fread(buf, 1, len, fp);
}

/* cdb_hash BUF LEN
 * Return the hash value of the LEN bytes at BUF. */
cdb_hash_t cdb_hash(const unsigned char *buf, const size_t len) {
    uint32_t h = 5381;
    size_t i;
    for (i = 0; i < len; ++i) {
        h = ((h << 5) + h) ^ buf[i];
    }
    return h;
}

/* cdb_hash_str STRING
 * Return the hash value of the given STRING. */
cdb_hash_t cdb_hash_str(const char *s) {
    return cdb_hash((unsigned char*)s, strlen(s));
}

/* cdb_hash_datum D
 * Return the hash value of the DATUM. */
cdb_hash_t cdb_hash_datum(const cdb_datum d) {
    return cdb_hash(d->cd_buf, d->cd_len);
}

/* cdb_open_fp FP
 * Open a CDB file for which a stdio file pointer FP is available. Returns a
 * cdb object on success or NULL on failure, setting cdb_errno. */
cdb cdb_open_fp(FILE *fp) {
    struct cdb *C = NULL, Cz = {0};
    unsigned char buf[HASHPTR_LEN];
    struct stat st;
    int i;

#define FAIL(e) do { cdb_errno = e; goto fail; } while (0)
    
    if (-1 == fstat(fileno(fp), &st))
        FAIL(errno);

    if (st.st_size < HASHPTR_LEN)
        FAIL(CDB_FILE_TOO_SMALL);

    if (!(C = malloc(sizeof *C)))
        FAIL(CDB_OUT_OF_MEMORY);

    /* XXX this will give a warning if we compile with 32-bit off_t; need to
     * add an appropriate conditional. */
    if (st.st_size > 0xffffffffll)
        FAIL(CDB_FILE_TOO_BIG);

    *C = Cz;
    C->c_fp = fp;
    C->c_st = st;

    if (HASHPTR_LEN != do_fread(fp, buf, HASHPTR_LEN)) {
        if (feof(fp))
            FAIL(CDB_FILE_TRUNCATED);
        else
            FAIL(errno);
    }

    for (i = 0; i < 256; ++i) {
        memcpy(&C->c_hashlocs[i].off, buf + 8 * i, 4);
        memcpy(&C->c_hashlocs[i].len, buf + 8 * i + 4, 4);
            /* byte ordering -- CDB is defined as a little-endian format, so
             * this is fine on i386, but not elsewhere. */
            /* NB len is in slots not bytes */
        if (C->c_hashlocs[i].off < HASHPTR_LEN
            || C->c_hashlocs[i].off > C->c_st.st_size
            || C->c_st.st_size - C->c_hashlocs[i].off < C->c_hashlocs[i].len * 8)
            FAIL(CDB_BAD_HASHLOC_PTR);
    }

    return C;
 
fail:
    free(C);
    return NULL;

#undef FAIL
}

/* yuk */
#define ALIGNMENT       4   /* __alignof(long double) on i386 */
typedef uint32_t ptr_int_t; /* XXX needs changing on 64-bit architectures */

/* cdb_datum_alloc LEN
 * Allocate space for a single cdb_datum holding up to LEN bytes. Free with
 * cdb_datum_free. Returns the newly-allocated datum on success or NULL on
 * failure (out of memory). */
cdb_datum cdb_datum_alloc(const size_t len) {
    cdb_datum d;
    if (!(d = malloc((sizeof *d) + ALIGNMENT + len))) {
        cdb_errno = CDB_OUT_OF_MEMORY;
        return NULL;
    }
    d->cd_buf = (void*)(((ptr_int_t)d + (sizeof *d) + ALIGNMENT) & ~(ALIGNMENT - 1));
    d->cd_len = len;
    return d;
}

/* cdb_datum_free D
 * Free storage associated with D. */
void cdb_datum_free(cdb_datum d) {
    if (d) free(d);
}

/* cdb_open FILE
 * Open the named CDB FILE, returning a cdb object on success or NULL on
 * failure, setting cdb_errno. */
cdb cdb_open(const char *name) {
    cdb C = NULL;
    FILE *fp;
    if (!(fp = fopen(name, "rb"))) {
        cdb_errno = errno;
        return NULL;
    } else if (!(C = cdb_open_fp(fp)))
        fclose(fp);
    else
        C->c_close_on_destroy = 1;
    return C;
}

/* cdb_close C
 * Free storage associated with C, and, if it was opened by cdb_open, also
 * close the associated file pointer. */
void cdb_close(cdb C) {
    if (!C) return;
    if (C->c_close_on_destroy)
        fclose(C->c_fp);
    free(C);
}

/* get_slot C OFFSET SLOT HASH WHERE
 * Save in *HASH and *WHERE the hash value and offset in the file pointed to by
 * the indexed SLOT in the hash table beginning at OFFSET. Returns 0 on success
 * or an error code on failure. */
static cdb_result_t get_slot(cdb C, const uint32_t offset, const uint32_t slot,
                cdb_hash_t *hash, uint32_t *where) {
    unsigned char buf[8];

    if (-1 == fseek(C->c_fp, offset + 8 * slot, SEEK_SET))
        return errno;
    
    if (8 != do_fread(C->c_fp, buf, 8)) {
        if (feof(C->c_fp))
            return CDB_FILE_TRUNCATED;
        else
            return errno;
    }

    memcpy(hash, buf, 4);
    memcpy(where, buf + 4, 4);
    
    return 0;
}

/* cdb_get C KEY
 * Look up the database entry identified by KEY. Returns the data retrieved on
 * success or NULL on failure, setting cdb_errno. The returned data should be
 * freed with cdb_datum_free. */
/* XXX add a mode where caller supplies storage */
cdb_datum cdb_get(cdb C, const cdb_datum key) {
    cdb_hash_t h, h8, sh;
    uint32_t slot0, slot;
    cdb_datum val = NULL;

#define FAIL(e) do { cdb_errno = e; goto fail; } while (0)

    if (key->cd_len > C->c_st.st_size)
        FAIL(CDB_NOT_FOUND);
    
    h = cdb_hash_datum(key);
    h8 = h & 0xff;
    
    debug("key len = %u", (unsigned)key->cd_len);
    debug("hash = %08x, hash255 = %02x", (unsigned)h, (unsigned)h8);

    if (!C->c_hashlocs[h8].off || !C->c_hashlocs[h8].len)
        FAIL(CDB_NOT_FOUND);

    debug("hash table %u starts at offset %u and has %u slots",
            (unsigned)h8,
            (unsigned)C->c_hashlocs[h8].off,
            (unsigned)C->c_hashlocs[h8].len);
    
    slot = slot0 = (h >> 8) % C->c_hashlocs[h8].len;

    debug("  %06x %% %u = %u", (unsigned)(h >> 8), C->c_hashlocs[h8].len, (unsigned)slot);
    
    do {
        unsigned char buf[8];
        uint32_t where, keylen, vallen;
        cdb_result_t e;

        debug("  looking in slot %u", (unsigned)slot);
        
        if ((e = get_slot(C, C->c_hashlocs[h8].off, slot, &sh, &where)))
            FAIL(e);

        debug("    hash = %08x, offset = %u", (unsigned)sh, (unsigned)where);
        
        if (sh == h) {
            if (0 == where)
                FAIL(CDB_NOT_FOUND);
            
            /* Have a potential slot. Grab the key and value length. */
            if (-1 == fseek(C->c_fp, where, SEEK_SET))
                FAIL(errno);
            else if (8 != do_fread(C->c_fp, buf, 8)) {
                if (feof(C->c_fp))
                    FAIL(CDB_FILE_TRUNCATED);
                else
                    FAIL(errno);
            }

            memcpy(&keylen, buf, 4);
            memcpy(&vallen, buf + 4, 4);

            debug("    key len = %u, val len = %u",
                    (unsigned)keylen, (unsigned)vallen);

            if (keylen == key->cd_len) {
                size_t i;
                for (i = 0; i < key->cd_len; ++i) {
                    int c;
                    if (EOF == (c = getc(C->c_fp))) {
                        if (feof(C->c_fp))
                            FAIL(CDB_FILE_TRUNCATED);
                        else
                            FAIL(errno);
                    } else if (c != (int)(((unsigned char*)key->cd_buf)[i]))
                        break;
                }

                if (i == key->cd_len) {
                    /* Got it. */
                    if (!(val = cdb_datum_alloc(vallen + 1)))
                        FAIL(CDB_OUT_OF_MEMORY);
                    /* Ensure NUL-terminated. */
                    ((char*)val->cd_buf)[vallen] = 0;
                    val->cd_len--;
                    if (val->cd_len != do_fread(C->c_fp, val->cd_buf,
                                                        val->cd_len)) {
                        if (feof(C->c_fp))
                            FAIL(CDB_FILE_TRUNCATED);
                        else
                            FAIL(errno);
                    } else
                        return val;
                }
            }
        }
        
        slot = (slot + 1) % C->c_hashlocs[h8].len;
    } while (slot != slot0);

    cdb_errno = CDB_NOT_FOUND;

fail:
    if (val) cdb_datum_free(val);
    return NULL;

#undef FAIL
}

/* cdb_get_string C STRING
 * As for cdb_get, but construct the KEY datum from STRING. */
cdb_datum cdb_get_string(cdb C, const char *s) {
    struct cdb_datum d;
    d.cd_len = strlen(s);
    d.cd_buf = (void*)s;
    return cdb_get(C, &d);
}

/* cdb_get_buf C BUF LEN
 * As for cdb_get, buf construct the KEY datum from BUF and LEN. */
cdb_datum cdb_get_buf(cdb C, const void *buf, const size_t len) {
    struct cdb_datum d;
    d.cd_len = len;
    d.cd_buf = (void*)buf;
    return cdb_get(C, &d);
}

/* cdb_strerror E
 * Return the text of the error message corresponding to E. */
char *cdb_strerror(const cdb_result_t e) {
    if (e > 0)
        return strerror(e);
    else if (e == 0)
        return "Success";
    else {
        switch (e) {
            case CDB_OUT_OF_MEMORY:
                return "Out of memory";
            case CDB_FILE_TOO_SMALL:
                return "File is too small to be a valid CDB file";
            case CDB_FILE_TOO_BIG:
                return "File is too large to be a valid CDB file";
            case CDB_BAD_HASHLOC_PTR:
                return "Bad hash-table location pointer in CDB file header";
            case CDB_BAD_RECORD_PTR:
                return "Bad record location pointer in CDB hash table";
            case CDB_NOT_FOUND:
                return "Record not found in CDB file";
            default:
                return "Unknown CDB internal error code";
        }
    }
}

#ifdef CDB_TEST_PROGRAM

/* 
 * Little test program -- reads keys as netstrings on standard input, and
 * writes on standard output either "X" for not found, or netstrings giving the
 * values of those keys.
 */

#include <ctype.h>

#define err(...)    \
        do { \
            fprintf(stderr, "cdbtest: "); \
            fprintf(stderr, __VA_ARGS__); \
            fprintf(stderr, "\n"); \
        } while (0)
#define die(...) do { err(__VA_ARGS__); exit(1); } while (0)

static cdb_datum netstring_read(FILE *fp) {
    unsigned int len = 0;
    int c;
    cdb_datum d;

#define FAIL(what)  \
        do { \
            if (feof(fp)) \
                die("%s: Premature EOF", what); \
            else \
                die("%s: %s", what, strerror(errno)); \
        } while (0)
    
    while (EOF != (c = getc(fp))) {
        if (isdigit(c))
            len = 10 * len + c - '0';
        else if (c == ':')
            break;
        else
            die("bad character '%c' in netstring length", c);
    }

    if (feof(fp) || ferror(fp))
        FAIL("while reading netstring length");

    if (!(d = cdb_datum_alloc(len)))
        die("while reading netstring: cdb_datum_alloc(%u): %s",
                len, cdb_strerror(cdb_errno));

    if (d->cd_len != do_fread(fp, d->cd_buf, d->cd_len))
        FAIL("while reading netstring data");
    
    if (EOF == (c = getc(fp))) {
        if (feof(fp))
            die("while reading netstring trailer: Premature EOF");
        else
            die("while reading netstring trailer: %s", strerror(errno));
    }

    return d;
}

void netstring_write(FILE *fp, const cdb_datum d) {
    fprintf(fp, "%u:", (unsigned)d->cd_len);
    if (d->cd_len != fwrite(d->cd_buf, 1, d->cd_len, fp))
        die("while writing netstring value: %s", strerror(errno));
    if (1 != fprintf(fp, ","))
        die("while writing netstring trailer: %s", strerror(errno));
}

/* main ARGC ARGV
 * Entry point. */
int main(int argc, char *argv[]) {
    cdb C;
    if (argc != 2)
        die("single argument should be name of CDB file");
    else if (!(C = cdb_open(argv[1])))
        die("%s: %s", argv[1], cdb_strerror(cdb_errno));

    while (1) {
        cdb_datum key, val;
        int c;

        c = getc(stdin);
        if ('X' == c)
            break;
        else
            ungetc(c, stdin);
        key = netstring_read(stdin);

        if (!(val = cdb_get(C, key))) {
            if (CDB_NOT_FOUND == cdb_errno)
                putc('X', stdout);
            else
                die("cdb_get: %s", cdb_strerror(cdb_errno));
        } else {
            netstring_write(stdout, val);
            cdb_datum_free(val);
        }
        fflush(stdout);
        
        cdb_datum_free(key);
    }

    cdb_close(C);

    return 0;
}

#endif /* CDB_TEST_PROGRAM */
