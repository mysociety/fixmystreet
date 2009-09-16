#!/usr/bin/perl -w
#
# Util.pm:
# Test Cobranding for FixMyStreet.
#
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: Util.pm,v 1.7 2009-09-16 17:00:36 louise Exp $

package Cobrands::Mysite::Util;
use Page;
use strict;
use Carp;
use mySociety::Web qw(ent);

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub site_name {
    return 'mysite';
}

sub site_restriction {
    return (' and council = 1 ', 99);
}

sub page {
    my %params = ();
    return ("A cobrand produced page", %params);
}

sub base_url {
    return 'http://mysite.example.com';
}

sub base_url_for_emails {
    return 'http://mysite.foremails.example.com';
}

sub disambiguate_location { 
    return 'Specific Location';
}

sub form_elements {
    return "Extra html";
}
1;
