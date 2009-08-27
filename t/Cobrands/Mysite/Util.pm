#!/usr/bin/perl -w
#
# Util.pm:
# Test Cobranding for FixMyStreet.
#
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: Util.pm,v 1.1 2009-08-27 08:42:46 louise Exp $

package Cobrands::Mysite::Util;
use Page;
use strict;
use Carp;
use mySociety::Web qw(ent);

sub new{
    my $class = shift;
    return bless {}, $class;
}

sub page{
   my %params = ();
   return ("A cobrand produced page", %params);
}

1;
