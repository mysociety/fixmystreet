/*
 * netstring.h:
 * Write netstrings into strings.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: netstring.h,v 1.1 2006-09-20 10:25:14 chris Exp $
 *
 */

#ifndef __NETSTRING_H_ /* include guard */
#define __NETSTRING_H_

#include <sys/types.h>

/* netstring.c */
size_t netstring_write(char *out, const void *buf, const size_t len);
size_t netstring_write_string(char *out, const char *str);
size_t netstring_write_int(char *out, const int i);

#endif /* __NETSTRING_H_ */
