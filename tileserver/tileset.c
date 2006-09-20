/*
 * tileset.c:
 * Interface to an individual tile set.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 */

static const char rcsid[] = "$Id: tileset.c,v 1.6 2006-09-20 16:44:53 chris Exp $";

/*
 * Tile sets are stored in directory trees which contain indices of tile
 * locations to tile IDs, packed archives of tile images, and indices of where
 * each tile image lives in the corresponding packed file. Tile IDs are SHA1
 * digests of the tile contents, enabling efficient storage in the presence of
 * repeated tiles.
 *
 * Note that this doesn't have attractive properties for locality of reference.
 * That will need fixing if performance under the current scheme is not
 * acceptable.
 */ 

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cdb.h"
#include "tileset.h"
#include "util.h"

#define TILEID_LEN  20

struct tileset {
    char *t_path, *t_pathbuf;
    cdb t_tileid_idx;
    /* Tile IDs are stored in the tile ID database in N-by-N square blocks,
     * so that the tile ID for (X, Y) is obtained by getting the block for
     * (X / N, Y / N) and looking up (X, Y) within it. The blocking factor is
     * (hopefully!) chosen to be about a disk block in size. It is stored in
     * the tile ID database. Rather than allocating a specific tile ID for a
     * tile which is not present, each information block is preceded by a
     * coverage bitmap. */
    unsigned t_blocking;
    bool t_first;
    unsigned t_x, t_y;
    cdb_datum t_block;
    /* File pointer open on an image file and the name of the file it's open
     * on. */
    char *t_imgfile;
    FILE *t_fpimg;
};


/* tileset_open PATH
 * Open the tileset at PATH, returning a tileset object on success or NULL on
 * failure. */
tileset tileset_open(const char *path) {
    struct tileset *T, Tz = {0};
    cdb_datum d = NULL;
    char *s;
    int i;

    T = xmalloc(sizeof *T);
    *T = Tz;

    T->t_first = 1;
    T->t_path = xstrdup(path);
    T->t_pathbuf = xmalloc(strlen(path) + sizeof "/tiles/a/b/c/tiles.cdb");
    
    /* Open the tile ID index. */
    sprintf(T->t_pathbuf, "%s/index.cdb", T->t_path);
    if (!(T->t_tileid_idx = cdb_open(T->t_pathbuf)))
        goto fail;

    /* get blocking factor */
    if (!(d = cdb_get_string(T->t_tileid_idx, "blocking")))
        goto fail;
    s = (char*)d->cd_buf;
    if (!(i = atoi(s)) || i < 0)
        goto fail;
    T->t_blocking = (unsigned)i;

    cdb_datum_free(d);

    return T;
    
fail:
    tileset_close(T);
    if (d) cdb_datum_free(d);
    return NULL;
}

/* tileset_close T
 * Free resources associated with T. */
void tileset_close(tileset T) {
    if (!T) return;
    cdb_close(T->t_tileid_idx);
    xfree(T->t_path);
    xfree(T->t_pathbuf);
    xfree(T);
}

/* tileset_path T
 * Return the path used to open T. */
char *tileset_path(tileset T) {
    return T->t_path;
}

static size_t blockmap_bitmap_len(const unsigned blocking) {
    return (blocking * blocking + 8) / 8;
}

static size_t blockmap_len(const unsigned blocking) {
    size_t l;
    /* Bitmap of null tiles. */
    l = blockmap_bitmap_len(blocking);
    /* Tile IDs themselves */
    l += blocking * blocking * TILEID_LEN;
    return l;
}

/* tileset_get_tileid T X Y ID
 * Write into ID the tile ID of the tile at (X, Y) in T, returning true on
 * success or false on failure. */
bool tileset_get_tileid(tileset T, const unsigned x, const unsigned y,
                        uint8_t *id) {
    unsigned x2, y2, off, off0;
    uint8_t *b;

    if (T->t_first || T->t_x != x || T->t_y != y) {
        /* Grab block from database. */
        char buf[32];

        T->t_first = 0;
        if (T->t_block) cdb_datum_free(T->t_block);
        
        sprintf(buf, "%u,%u", x / T->t_blocking, y / T->t_blocking);
        if (!(T->t_block = cdb_get_string(T->t_tileid_idx, buf)))
            return 0;
    }

    if (T->t_block->cd_len != blockmap_len(T->t_blocking))
        return 0;
        /* XXX also report bogus ID block */

    b = (uint8_t*)T->t_block->cd_buf;

    x2 = x % T->t_blocking;
    y2 = y % T->t_blocking;
    off = (x2 + y2 * T->t_blocking);

    /* For a tile not present the corresponding bit in the bitmap is set. */
    if (b[off >> 3] & (1 << (off & 7)))
        return 0;

    off0 = blockmap_bitmap_len(T->t_blocking);
    memcpy(id, b + off0 + off * TILEID_LEN, TILEID_LEN);

    return 1;
}

/* tileset_get_tile T ID LEN
 * Retrieve the tile identified by ID, writing its length into *LEN and
 * returning a malloced buffer containing its contents on success, or returning
 * NULL on failure. */
void *tileset_get_tile(tileset T, const uint8_t *id, size_t *len) {
    cdb idx = NULL;
    cdb_datum d = NULL;
    void *ret = NULL;
    unsigned off;
    FILE *fp = NULL;

    sprintf(T->t_pathbuf, "%s/tiles/%x/%x/%x/tiles.cdb",
                T->t_path, (unsigned)(id[0] >> 4),
                (unsigned)(id[0] & 0xf), (unsigned)(id[1] >> 4));
    if (!(idx = cdb_open(T->t_pathbuf)))
        return NULL;
        /* also maybe report bogus index */
    
    if (!(d = cdb_get_buf(idx, id, TILEID_LEN)))
        goto fail;

    if (2 != sscanf((char*)d->cd_buf, "%x:%x", &off, len))
        goto fail;

    sprintf(T->t_pathbuf, "%s/tiles/%x/%x/%x/tiles",
                T->t_path, (unsigned)(id[0] >> 4),
                (unsigned)(id[0] & 0xf), (unsigned)(id[1] >> 4));
    if (!(fp = fopen(T->t_pathbuf, "rb")))
        goto fail;
    else if (-1 == fseek(fp, off, SEEK_SET))
        goto fail;

    ret = xmalloc(*len);
    if (*len != fread(ret, 1, *len, fp)) {
        xfree(ret);
        goto fail;
    }

fail:
    if (idx) cdb_close(idx);
    if (d) cdb_datum_free(d);
    if (fp) fclose(fp);
    return ret;
}
