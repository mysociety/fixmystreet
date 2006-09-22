/*
 * tileserver.c:
 * Serve map tiles and information about map tiles.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 */

static const char rcsid[] = "$Id: tileserver.c,v 1.10 2006-09-22 12:25:43 chris Exp $";

/* 
 * This is slightly complicated by the fact that we indirect tile references
 * via hashes of the tiles themselves. We support the following queries:
 *
 * http://host/path/tileserver/TILESET/HASH
 *      to get an individual tile image in TILESET identified by HASH;
 * http://host/path/tileserver/TILESET/E,N/FORMAT
 *      to get the identity of the tile at (E, N) in TILESET in the given
 *      FORMAT;
 * http://host/path/tileserver/TILESET/W-E,S-N/FORMAT
 *      to get the identities of the tiles in the block with SW corner (W, S)
 *      and NE corner (E, N) in the given FORMAT.
 * 
 * What FORMATS should we support? RABX and JSON are the obvious ones I guess.
 * Add TEXT for debugging.
 */

#include <sys/types.h>

#include <errno.h>
#ifndef NO_FASTCGI
#include <fcgi_stdio.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <sys/stat.h>

#include "base64.h"
#include "netstring.h"
#include "tileset.h"
#include "util.h"

/* tiles_basedir
 * The configured path to tilesets. */
static char *tiles_basedir;

#define HTTP_BAD_REQUEST            400
#define HTTP_UNAUTHORIZED           401
#define HTTP_FORBIDDEN              403
#define HTTP_NOT_FOUND              404
#define HTTP_INTERNAL_SERVER_ERROR  500
#define HTTP_NOT_IMPLEMENTED        501
#define HTTP_SERVICE_UNAVAILABLE    503

/* error STATUS TEXT
 * Send an error to the client with the given HTTP STATUS and TEXT. */
void error(int status, const char *s) {
    if (status < 100 || status > 999)
        status = 500;
    printf(
        "Status: %03d\r\n"
        "Content-Type: text/plain; charset=us-ascii\r\n"
        "Content-Length: %u\r\n"
        "\r\n"
        "%s\n",
        status,
        strlen(s) + 1,
        s);
}

/* struct request
 * Definition of a request we handle. */
struct request {
    char *r_tileset;
    enum {
        FN_GET_TILE = 0,
        FN_GET_TILEIDS
    } r_function;

    uint8_t r_tileid[TILEID_LEN];

    int r_west, r_east, r_south, r_north;
    enum {
        F_RABX,
        F_JSON,
        F_TEXT,
        F_HTML
    } r_format;

    char *r_buf;
};

void request_free(struct request *R);

/* request_parse PATHINFO
 * Parse a request from PATHINFO. Returns a request on success or NULL on
 * failure. */
struct request *request_parse(const char *path_info) {
    const char *p, *q;
    struct request *R = NULL, Rz = {0};

    /* Some trivial syntax checks. */
    if (!*path_info || *path_info == '/' || !strchr(path_info, '/')) {
        err("PATH_INFO of \"%s\" is not a valid request", path_info);
        return NULL;
    }
    
   
    /* 
     * TILESET/HASH
     * TILESET/E,N/FORMAT
     * TILESET/W-E,S-N/FORMAT
     */

    /* Tileset name consists of alphanumerics and hyphen. */
    p = path_info + strspn(path_info,
                            "0123456789"
                            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                            "abcdefghijklmnopqrstuvwxyz"
                            "-");

    if (*p != '/')
        return NULL;

    R = xmalloc(sizeof *R);
    *R = Rz;
    R->r_buf = xmalloc(strlen(path_info) + 1);
    R->r_tileset = R->r_buf;

    strncpy(R->r_tileset, path_info, p - path_info);
    R->r_tileset[p - path_info] = 0;

    ++p;

    /* Mode. */
    if ((q = strchr(p, '/'))) {
        /* Tile IDs request. */
        R->r_function = FN_GET_TILEIDS;

        /* Identify format requested. */
        ++q;
        if (!strcmp(q, "RABX"))
            R->r_format = F_RABX;
        else if (!strcmp(q, "JSON"))
            R->r_format = F_JSON;
        else if (!strcmp(q, "text"))
            R->r_format = F_TEXT;
        else if (!strcmp(q, "html"))
            R->r_format = F_HTML;
        else {
            err("request for unknown tile ID result format \"%s\"", q);
            goto fail;
        }

        if (4 == sscanf(p, "%d-%d,%d-%d",
                        &R->r_west, &R->r_east, &R->r_south, &R->r_north)) {
            if (R->r_west < 0 || R->r_south < 0
                || R->r_east < R->r_west || R->r_north < R->r_south) {
                err("area range query has invalid coordinates or order");
                goto fail;
            } else
                return R;
        } else if (2 == sscanf(p, "%d,%d", &R->r_west, &R->r_south)) {
            R->r_east = R->r_west;
            R->r_north = R->r_south;
            if (R->r_west < 0 || R->r_south < 0) {
                err("tile ID query has negative coordinates");
                goto fail;
            } else
                return R;
        }
    } else {
        size_t l;

        /* Tile request. */
        R->r_function = FN_GET_TILE;
        if (strlen(p) != TILEID_LEN_B64)
            goto fail;

        /* Decode it. Really this is "base64ish", so that we don't have to
         * deal with '+' or '/' in the URL. */
        base64_decode(p, R->r_tileid, &l, 1);
        if (l != TILEID_LEN)
            goto fail;

        return R;
    }
    
fail:
    request_free(R);
    return NULL;
}

/* request_free R
 * Free storage allocated for R. */
void request_free(struct request *R) {
    if (!R) return;
    xfree(R->r_buf);
    xfree(R);
}

void handle_request(void) {
    char *path_info;
    struct request *R;
    static char *path;
    static size_t pathlen;
    size_t l;
    tileset T;
    time_t now;
    struct tm *tm;
    char date[32];
    const char *last_modified = "Wed, 20 Sep 2006 17:27:40 GMT";
    const unsigned cache_max_age = 365 * 86400;

    /* Date: header is required if we give a 304 Not Modified response. */
    time(&now);
    tm = gmtime(&now);
    strftime(date, sizeof date, "%a, %d %b %Y %H:%M:%S GMT", tm);
    
    /* All requests are given via PATH_INFO. */
    if (!(path_info = getenv("PATH_INFO"))) {
        error(400, "No request path supplied");
        return;
    }

    if ('/' == *path_info)
        ++path_info;

    if (!(R = request_parse(path_info))) {
        error(400, "Bad request");
        return;
    }

    /* So we have a valid request. */
    l = strlen(R->r_tileset) + strlen(tiles_basedir) + 2;
    if (pathlen < l)
        path = xrealloc(path, pathlen = l);
    sprintf(path, "%s/%s", tiles_basedir, R->r_tileset);
   
    if (!(T = tileset_open(path))) {
        error(404, "Tileset not found");
            /* XXX assumption about the nature of the error */
        request_free(R);
        return;
    }

    /* XXX this is poor -- if the client sends If-Modified-Since: we just
     * assume that it hasn't been. We might want to do something more clever at
     * some point. */
    if (getenv("HTTP_IF_MODIFIED_SINCE")) {
        printf(
            "Status: 304 Not Modified\r\n"
            "Date: %s\r\n"
            "\r\n", date);
        tileset_close(T);
        request_free(R);
        return;
    }

    if (FN_GET_TILE == R->r_function) {
        /* 
         * Send a single tile image to the client.
         */
        void *buf;
        size_t len;

        if ((buf = tileset_get_tile(T, R->r_tileid, &len))) {
            printf(
                "Content-Type: image/png\r\n"
                "Content-Length: %u\r\n"
                "Last-Modified: %s\r\n"
                "Date: %s\r\n"
                "Cache-Control: max-age=%u\r\n"
                "\r\n", len, last_modified, date, cache_max_age);
            fwrite(buf, 1, len, stdout);
            xfree(buf);
        } else
            error(404, "Tile not found");
                /* XXX error assumption */
    } else if (FN_GET_TILEIDS == R->r_function) {
        /*
         * Send one or more tile IDs to the client, in some useful format.
         */
        unsigned x, y;
        static char *buf;
        static size_t buflen, n;
        unsigned rows, cols;
        char *p;

        rows = R->r_north + 1 - R->r_south;
        cols = R->r_east + 1 - R->r_west;
        n = cols * rows;
        if (buflen < n * TILEID_LEN_B64 + 256)
            buf = xrealloc(buf, buflen = n * TILEID_LEN_B64 + 256);

        /* Send start of array in whatever format. */
        p = buf;
        switch (R->r_format) {
            case F_RABX:
                /* Format as array of arrays. */
                *(p++) = 'L';
                p += netstring_write_int(p, (int)rows);
                break;

            case F_JSON:
                /* Ditto. */
                *(p++) = '[';
                break;

            case F_TEXT:
                /* Space and LF separated matrix so no special leader. */
                break;

            case F_HTML:
                strcpy(p,
                    "<html><head><title>tileserver test</title></head><body>");
                p += strlen(p);

                if (R->r_west > 0)
                    p += sprintf(p, "<a href=\"../%u-%u,%u-%u/html\">west</a> ",
                                R->r_west - 1, R->r_east - 1,
                                R->r_south, R->r_north);
                p += sprintf(p, "<a href=\"../%u-%u,%u-%u/html\">east</a> ",
                            R->r_west + 1, R->r_east + 1,
                            R->r_south, R->r_north);

                p += sprintf(p, "<a href=\"../%u-%u,%u-%u/html\">north</a> ",
                            R->r_west, R->r_east,
                            R->r_south + 1, R->r_north + 1);
                if (R->r_south > 0)
                    p += sprintf(p, "<a href=\"../%u-%u,%u-%u/html\">south</a> ",
                                R->r_west, R->r_east,
                                R->r_south - 1, R->r_north - 1);
                p += sprintf(p, "<br>");
                break;
        }

        /* Iterate over tile IDs. */
        for (y = R->r_north; y >= R->r_south; --y) {
            switch (R->r_format) {
                case F_RABX:
                    *(p++) = 'L';
                    p += netstring_write_int(p, (int)cols);
                    break;

                case F_JSON:
                    *(p++) = '[';
                    break;

                case F_TEXT:
                    break;  /* nothing */

                case F_HTML:
                    break;  /* nothing */
            }
            
            for (x = R->r_west; x <= R->r_east; ++x) {
                uint8_t id[TILEID_LEN];
                char idb64[TILEID_LEN_B64 + 1];
                bool isnull = 0;
                
                if (!(tileset_get_tileid(T, x, y, id)))
                    isnull = 1;
                else
                    base64_encode(id, TILEID_LEN, idb64, 1, 1);

                if (p + 256 > buf + buflen) {
                    size_t n;
                    n = p - buf;
                    buf = xrealloc(buf, buflen *= 2);
                    p = buf + n;
                }

                switch (R->r_format) {
                    case F_RABX:
                        if (isnull)
                            *(p++) = 'N';
                        else {
                            *(p++) = 'T';
                            p += netstring_write_string(p, idb64);
                        }
                        break;

                    case F_JSON:
                        if (isnull) {
                            strcpy(p, "null");
                            p += 4;
                        } else {
                            *(p++) = '"';
                            strcpy(p, idb64);
                            p += TILEID_LEN_B64;
                            *(p++) = '"';
                        }
                        if (x < R->r_east)
                            *(p++) = ',';
                        break;

                    case F_TEXT:
                        if (isnull)
                            *(p++) = '-';
                        else {
                            strcpy(p, idb64);
                            p += TILEID_LEN_B64;
                        }
                        if (x < R->r_east)
                            *(p++) = ' ';
                        break;

                    case F_HTML:
                        if (isnull)
                            ;   /* not much we can do without the tile sizes */
                        else
                            p += sprintf(p,
                                    "<img title=\"%u,%u\" src=\"../%s\">",
                                    x, y,
                                    idb64);
                        break;
                }
            }

            switch (R->r_format) {
                case F_RABX:
                    break;  /* no row terminator */

                case F_JSON:
                    *(p++) = ']';
                    if (y < R->r_north)
                        *(p++) = ',';
                    break;

                case F_TEXT:
                    *(p++) = '\n';
                    break;

                case F_HTML:
                    p += sprintf(p, "<br>");
                    break;
            }
        }

        /* Array terminator. */
        switch (R->r_format) {
            case F_RABX:
                break;

            case F_JSON:
                *(p++) = ']';
                break;
                
            case F_TEXT:
                break;

            case F_HTML:
                p += sprintf(p, "</body></html>");
        }
        /* NB no terminating NUL */

        /* Actually send it. */
        printf("Content-Type: ");
        switch (R->r_format) {
            case F_RABX:
                printf("application/octet-stream");
                break;

            case F_JSON:
                /* Not really clear what CT to use here but Yahoo use
                 * "text/javascript" and presumably they've done more testing
                 * than us.... */
                printf("text/javascript");
                break;

            case F_TEXT:
                printf("text/plain; charset=us-ascii");
                break;

            case F_HTML:
                printf("text/html; charset=us-ascii");
                break;
        }
        printf("\r\n"
            "Content-Length: %u\r\n"
            "Last-Modified: %s\r\n"
            "Date: %s\r\n"
            "Cache-Control: max-age=%u\r\n"
            "\r\n",
            (unsigned)(p - buf), last_modified, date, cache_max_age);

        fwrite(buf, 1, p - buf, stdout);
    }

    tileset_close(T);
    request_free(R);
}

int main(int argc, char *argv[]) {
    struct stat st;
    bool initialised = 0;

#ifndef NO_FASTCGI
    while (FCGI_Accept() >= 0)
#endif
                               {
        /* Stupid order since with fcgi_stdio if we haven't called FCGI_Accept
         * we don't get any stderr output.... */
        if (!initialised) {
            if (argc != 2)
                die("single argument is path to tile sets");
            tiles_basedir = argv[1];
            if (-1 == stat(tiles_basedir, &st))
                die("%s: stat: %s", tiles_basedir, strerror(errno));
            else if (!S_ISDIR(st.st_mode))
                die("%s: Not a directory", tiles_basedir);
            initialised = 1;
        }

        handle_request();
    }

    return 0;
}
