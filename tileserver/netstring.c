/*
 * netstring.c:
 * Write netstrings to strings.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 */

static const char rcsid[] = "$Id: netstring.c,v 1.1 2006-09-20 10:25:14 chris Exp $";

#include <sys/types.h>
#include <stdio.h>
#include <string.h>

/* netstring_write OUT BUFFER LEN
 * Write the LEN-byte BUFFER to OUT as a netstring, returning the number of
 * bytes. If OUT is NULL, returns the number of bytes required. */
size_t netstring_write(char *out, const void *buf, const size_t len) {
    size_t l = 0;
    char dummy[32];
    l += sprintf(out ? out : dummy, "%u:", (unsigned)len);
    if (out) memcpy(p, buf, len);
    l += len;
    if (out) buf[l] = ',';
    ++l;
    return l;
}

/* netstring_write_string OUT STRING
 * Write the NUL-terminated STRING to OUT as a netstring, returning the number
 * of bytes used. If OUT is NULL, return the number of bytes required. */
size_t netstring_write_string(char *out, const char *str) {
    return netstring_write(out, str, strlen(str));
}

/* netstring_write_string OUT I
 * Write I to OUT as a decimal integer formatted as a netstring, returning the
 * number of bytes used. If OUT is NULL, return the number of bytes required. */
size_t netstring_write_int(char *out, const int i) {
    char str[32];
    sprintf(str, "%d", i);
    return netstring_write_string(out, str);
}
