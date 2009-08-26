#!/usr/bin/perl -w
#
# MockQuery.pm:
# Mock query to support tests for the Page functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: MockQuery.pm,v 1.1 2009-08-26 16:52:14 louise Exp $
#


package MockQuery;

sub new{
    my $class = shift;
    my $self = {
     site => shift,
    };
    bless $self, $class;
    return $self;
}

sub header{
  
}

1;
