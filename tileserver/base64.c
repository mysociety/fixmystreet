/*
 * base64.c:
 * Base64 and "base64ish" encoding and decoding.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 */

static const char rcsid[] = "$Id: base64.c,v 1.1 2006-09-20 10:25:14 chris Exp $";

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

static const char b64chars[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    "0123456789"
    "+/=";

static const char b64ishchars[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    "0123456789"
    "-_=";

/* base64_encode IN INLEN OUT B64ISH NOPAD
 * Encode INLEN bytes at IN into the buffer at OUT. The total number of bytes
 * written is recorded in *OUTLEN. OUT must have space for at least
 * 1 + 4 * (INLEN + 3) / 3 + 1 bytes. Returns a pointer to OUT. This function
 * always succeeds. If B64ISH is true, the alternate "base64ish" alphabet is
 * used instead of the standard one. If NOPAD is true, "=" padding is not added
 * at the end of the transformed buffer. */
char *base64_encode(const void *in, const size_t inlen, char *out,
                        const bool b64ish, const bool nopad) {
    const char *alphabet;
    const uint8_t *b;
    char *p;
    size_t i;

    alphabet = b64ish ? b64ishchars : b64chars;
    b = (const uint8_t*)in;

    for (i = 0, p = out; i < inlen; i += 3) {
        uint8_t bb[3] = {0};
        unsigned j;
        size_t n, k;

        n = inlen - i;
        if (n > 3) n = 3;
        for (k = 0; k < n; ++k) bb[k] = b[i + k];

        j = bb[0] >> 2;
        *(p++) = alphabet[j];

        j = ((bb[0] & 3) << 4) | (bb[1] >> 4);
        *(p++) = alphabet[j];

        if (n == 1) {
            if (!nopad) {
                *(p++) = '=';
                *(p++) = '=';
            }
            break;
        }

        j = ((bb[1] & 0xf) << 2) | (bb[2] >> 6);
        *(p++) = alphabet[j];
        if (n == 2) {
            if (!nopad)
                *(p++) = '=';
            break;
        }

        j = bb[2] & 0x3f;
        *(p++) = alphabet[j];
    }

    *p = 0;

    return out;
}

/* base64_decode IN OUT OUTLEN B64ISH
 * Decode the string at IN into OUT. If B64ISH is true, the alternate
 * "base64ish" alphabet is used instead of the standard one. Returns the number
 * of characters consumed and saves the number of output bytes decoded in
 * *OUTLEN; the number of characters consumed will be smaller than the length
 * of the input string if an invalid character was encountered in IN. OUT must
 * have space for at least 3 * (INLEN / 4) bytes of output. */
size_t base64_decode(const char *in, void *out, size_t *outlen,
                        const bool b64ish) {
    const char *alphabet;
    uint8_t *b;
    size_t inlen = 0, consumed = 0, len = 0, i;

    inlen = strlen(in);
    alphabet = b64ish ? b64ishchars : b64chars;
    b = (uint8_t*)out;
    
    for (i = 0; i < inlen; i += 4) {
        char bb[5] = "====";
        size_t n, j;
        const char *p;
        
        n = inlen - i;
        if (n > 4) n = 4;
        memcpy(bb, in + i, n);

        if (!(p = strchr(alphabet, bb[0])))
            break;
        j = p - alphabet;
        b[len] = (uint8_t)(j << 2);
        ++consumed;

        if (!(p = strchr(alphabet, bb[1])))
            break;
        j = p - alphabet;
        b[len++] |= (uint8_t)(j >> 4);
        b[len] = (uint8_t)(j << 4);
        ++consumed;

        if ('=' == bb[2]) {
            ++consumed;
            if ('=' == *p) ++consumed; /* potentially skip last char */
            break;
        } else if (!(p = strchr(alphabet, bb[2])))
            break;
        j = p - alphabet;
        b[len++] |= (uint8_t)(j >> 2);
        b[len] = (uint8_t)(j << 6);
        ++consumed;

        if ('=' == bb[3]) {
            ++consumed;
            break;
        } else if (!(p = strchr(alphabet, bb[3])))
            break;
        j = p - alphabet;
        b[len++] |= (uint8_t)j;
        ++consumed;
    }

    *outlen = len;
    return consumed;
}

#ifdef BASE64_TEST_PROGRAM

/*
 * Small test program -- reads base64-encoded or raw data on standard input,
 * and writes on standard output the decoded/encoded version. Driven by
 * base64test.
 */

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#define err(...)    \
        do { \
            fprintf(stderr, "base64test: "); \
            fprintf(stderr, __VA_ARGS__); \
            fprintf(stderr, "\n"); \
        } while (0)
#define die(...) do { err(__VA_ARGS__); exit(1); } while (0)

struct datum {
    void *buf;
    size_t len;
};

static struct datum *netstring_read(FILE *fp) {
    unsigned int len = 0;
    int c;
    struct datum *d;

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

    if (!(d = malloc((sizeof *d) + len + 1)))
        die("malloc: %s", strerror(errno));
    d->buf = (char*)d + (sizeof *d);
    d->len = len;
    ((char*)d->buf)[len] = 0;   /* ensure NUL-terminated */

    if (d->len != fread(d->buf, 1, d->len, fp))
        FAIL("while reading netstring data");
    
    if (EOF == (c = getc(fp))) {
        if (feof(fp))
            die("while reading netstring trailer: Premature EOF");
        else
            die("while reading netstring trailer: %s", strerror(errno));
    }

    return d;
}

void netstring_write(FILE *fp, const struct datum *d) {
    fprintf(fp, "%u:", (unsigned)d->len);
    if (d->len != fwrite(d->buf, 1, d->len, fp))
        die("while writing netstring value: %s", strerror(errno));
    if (1 != fprintf(fp, ","))
        die("while writing netstring trailer: %s", strerror(errno));
}

/* main ARGC ARGV
 * Entry point. */
int main(int argc, char *argv[]) {
    while (1) {
        int c;
        struct datum *d, d2;
        size_t l;

        if (EOF == (c = getc(stdin)))
            die("premature EOF reading command character");
        else if ('X' == c)
            break;

        d = netstring_read(stdin);
        
        switch (c) {
            case 'B':   /* base64 */
            case 'b':   /* base64ish */
                if (!(d2.buf = malloc(d->len)))
                    die("malloc: %s", strerror(errno));
                l = base64_decode(d->buf, d2.buf, &d2.len, c == 'b');
                netstring_write(stdout, &d2);
                free(d2.buf);
                break;

            case 'R':   /* to base64 */
            case 'r':   /* to base64ish */
                if (!(d2.buf = malloc(1 + 4 * (1 + d->len / 3))))
                    die("malloc: %s", strerror(errno));
                base64_encode(d->buf, d->len, d2.buf, c == 'r', 0);
                d2.len = strlen((char*)d2.buf);
                netstring_write(stdout, &d2);
                free(d2.buf);
                break;

            default:
                die("bad command character '%c'", c);
        }

        free(d);
        fflush(stdout);
    }
    return 0;
}

#endif /* BASE64_TEST_PROGRAM */
