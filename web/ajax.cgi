#!/usr/bin/perl -w -I../perllib

# ajax.cgi:
# Updating the pins as you drag the map
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: ajax.cgi,v 1.19 2009-12-15 17:53:52 louise Exp $

use strict;
use Standard;
use mySociety::Web qw(ent NewURL);

sub main {
    my $q = shift;

    my @vars = qw(x y sx sy all_pins);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my %input_h = map { $_ => $q->param($_) ? ent($q->param($_)) : '' } @vars;

    # Our current X/Y middle of visible map
    my $x = $input{x};
    my $y = $input{y};
    $x ||= 0; $x += 0;
    $y ||= 0; $y += 0;

    # Where we started as that's the (0,0) we have to work to
    my $sx = $input{sx};
    my $sy = $input{sy};
    $sx ||= 0; $sx += 0;
    $sy ||= 0; $sy += 0;

    my $interval;
    unless ($input{all_pins}) {
        $interval = '6 months';
    }
    my ($pins, $on_map, $around_map, $dist) = FixMyStreet::Map::map_pins($q, $x, $y, $sx, $sy, $interval);
    my $cobrand = Page::get_cobrand($q);
    my $list = '';
    my $link = '';
    foreach (@$on_map) {
        $link = Cobrand::url($cobrand, NewURL($q, -retain => 1, 
                                                  -url => '/report/' . $_->{id}, 
                                                  pc => undef, 
                                                  x => undef, 
                                                  y => undef, 
                                                  sx => undef, 
                                                  sy => undef, 
                                                  all_pins => undef, 
                                                  no_pins => undef), $q);  
        $list .= '<li><a href="' . $link . '">';
        $list .= ent($_->{title}) . '</a> <small>(';
        $list .= Page::prettify_epoch($q, $_->{time}, 1) . ')</small>';
        $list .= ' <small>' . _('(fixed)') . '</small>' if $_->{state} eq 'fixed';
        $list .= '</li>';
    }
    my $om_list = $list;

    $list = '';
    foreach (@$around_map) {
        my $dist = int($_->{distance}*10+.5)/10;
        $link = Cobrand::url($cobrand, NewURL($q, -retain => 1, 
                                                  -url => '/report/' . $_->{id}, 
                                                  pc => undef, 
                                                  x => undef, 
                                                  y => undef, 
                                                  sx => undef, 
                                                  sy => undef, 
                                                  all_pins => undef, 
                                                  no_pins => undef), $q);  
        $list .= '<li><a href="' . $link . '">';
        $list .= ent($_->{title}) . '</a> <small>(';
        $list .= Page::prettify_epoch($q, $_->{time}, 1) . ', ';
        $list .= $dist . 'km)</small>';
        $list .= ' <small>' . _('(fixed)') . '</small>' if $_->{state} eq 'fixed';
        $list .= '</li>';
    }
    my $am_list = $list;

    #$list = '';
    #foreach (@$fixed) {
    #    $list .= '<li><a href="/report/' . $_->{id} . '">';
    #    $list .= $_->{title} . ' <small>(' . int($_->{distance}*10+.5)/10 . 'km)</small>';
    #    $list .= '</a></li>';
    #}
    #my $f_list = $list;

    # For now, assume this is not cacheable - may need to be more fine-grained later
    print $q->header(-charset => 'utf-8', -content_type => 'text/javascript', -Cache_Control => 'max-age=0');
  

    $pins =~ s/'/\\'/g;
    $om_list =~ s/'/\\'/g;
    $am_list =~ s/'/\\'/g;
    #$f_list =~ s/'/\\'/g;
    print <<EOF;
({
'pins': '$pins',
'current': '$om_list',
'current_near': '$am_list'
})
EOF
}

Page::do_fastcgi(\&main);

