#
# Makefile:
# Build pnmtilesplit.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Makefile,v 1.1 2006-09-13 18:40:29 chris Exp $
#

CFLAGS = -Wall -g
LDFLAGS =
LDLIBS = -lnetpbm		# is this a debianism?

pnmtilesplit: pnmtilesplit.c
	$(CC) $(CFLAGS) pnmtilesplit.c $(LDFLAGS) $(LDLIBS) -o pnmtilesplit

clean:
	rm -f pnmtilesplit *~ core
