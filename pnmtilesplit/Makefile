#
# Makefile:
# Build pnmtilesplit.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Makefile,v 1.2 2006-09-14 17:21:03 chris Exp $
#

CFLAGS = -Wall -g -O99
LDFLAGS =
LDLIBS = -lnetpbm		# is this a debianism?

pnmtilesplit: pnmtilesplit.c
	$(CC) $(CFLAGS) pnmtilesplit.c $(LDFLAGS) $(LDLIBS) -o pnmtilesplit

clean:
	rm -f pnmtilesplit *~ core
