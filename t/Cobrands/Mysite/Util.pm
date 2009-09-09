#!/usr/bin/perl -w
#
# Util.pm:
# Test Cobranding for FixMyStreet.
#
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: Util.pm,v 1.3 2009-09-09 15:29:27 louise Exp $

package Cobrands::Mysite::Util;
use Page;
use strict;
use Carp;
use mySociety::Web qw(ent);

sub new{
    my $class = shift;
    return bless {}, $class;
}

sub site_name{
    return 'mysite';
}

sub site_restriction{
    return (' and council = 1 ', 99);
}

sub page{
    my %params = ();
    return ("A cobrand produced page", %params);
}

sub base_url{
    return 'mysite.example.com';
}

1;
