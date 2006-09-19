#!/usr/bin/perl -w

# convertLB.pl:
# Out of date tile conversion
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: convertLB.pl,v 1.1 2006-09-19 15:08:36 matthew Exp $

use strict;

my @squares = (
    '', '', '', '', 'HP', '', '',
    '', '', '', 'HT', 'HU', '', '',
    '', 'HW', 'HX', 'HY', 'HZ', '', '',
    'NA', 'NB', 'NC', 'ND', '', '', '',
    'NF', 'NG', 'NH', 'NJ', 'NK', '', '',
    'NL', 'NM', 'NN', 'NO', '', '', '', 
    '', 'NR', 'NS', 'NT', 'NU', '', '',
    '', 'NW', 'NX', 'NY', 'NZ', 'OV', '',
    '', '', 'SC', 'SD', 'SE', 'TA', '',
    '', '', 'SH', 'SJ', 'SK', 'TF', 'TG',
    '', 'SM', 'SN', 'SO', 'SP', 'TL', 'TM',
    '', 'SR', 'SS', 'ST', 'SU', 'TQ', 'TR',
    'SV', 'SW', 'SX', 'SY', 'SZ', 'TV', '');

my %squares;
my $i = 0;
foreach my $square (@squares) {
    $squares{$square} = $i if $square;
    $i++;
}

for (<tl/*.png>) {
    /^tl\/(\d+)\.(\d+)\.png$/ or die;
    my $x = $1;
    my $y = $2;
    my $partb_col = $x%16;
    my $partb_row = $y%16;
    my $parta_col = int($x/16)%10;
    my $parta_row = 9 - int($y/16)%10;
    my $square_col = int(int($x/16)/10);
    my $square_row = int(int($y/16)/10);
    
    my $square = $squares[$square_row*7+$square_col];
    my $parta = 10*$parta_col+$parta_row;
    my $partb = $partb_col+$partb_row*16;
#    print "$_ : $square$parta-$partb.png\n";
    system("mv $_ tl/$square$parta-$partb.png");
}
