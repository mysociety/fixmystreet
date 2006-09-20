/*
 * tileset.h:
 * Interface to an individual tile set.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: tileset.h,v 1.1 2006-09-20 10:25:14 chris Exp $
 *
 */

#ifndef __TILESET_H_ /* include guard */
#define __TILESET_H_

#include <stdbool.h>
#include <stdint.h>

#define TILEID_LEN      20
#define TILEID_LEN_B64  27

typedef struct tileset *tileset;

/* tileset.c */
tileset tileset_open(const char *path);
void tileset_close(tileset T);
bool tileset_get_tileid(tileset T, const unsigned x, const unsigned y,
                            uint8_t *id);
void *tileset_get_tile(tileset T, const uint8_t *id, size_t *len);

#endif /* __TILESET_H_ */
