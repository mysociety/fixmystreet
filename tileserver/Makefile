#
# Makefile:
# Build tile server.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Makefile,v 1.1 2006-09-20 15:45:51 chris Exp $
#

CFLAGS = -Wall -g -O99 -I/software/include
LDFLAGS = -L/software/lib
LDLIBS = -lfcgi

# for debugging
#CFLAGS += -DNO_FASTCGI

SRCS = base64.c cdb.c netstring.c tileserver.c tileset.c util.c
OBJS = $(SRCS:.c=.o)
HDRS = base64.h cdb.h netstring.h tileset.h util.h
TXTS = 

tileserver: Makefile $(OBJS)
	$(CC) -o tileserver $(OBJS) $(LDFLAGS) $(LDLIBS)

clean:
	rm -f tileserver $(OBJS) *~ core

%.o:    %.c Makefile
	$(CC) $(CFLAGS) -c -o $@ $<

