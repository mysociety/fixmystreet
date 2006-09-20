/*
 * base64.h:
 * Base64 and "base64ish" encoding and decoding.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: base64.h,v 1.2 2006-09-20 13:22:58 chris Exp $
 *
 */

#ifndef __BASE64_H_ /* include guard */
#define __BASE64_H_

#include <sys/types.h>

#include <stdbool.h>

/* base64.c */
char *base64_encode(const void *in, const size_t inlen, char *out,
                        const bool b64ish, const bool nopad);
size_t base64_decode(const char *in, void *out, size_t *outlen,
                        const bool b64ish);

#endif /* __BASE64_H_ */
