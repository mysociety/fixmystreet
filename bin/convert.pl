#!/usr/bin/perl -w

# convert.pl:
# Out of date tile conversion
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: convert.pl,v 1.1 2006-09-19 15:08:36 matthew Exp $

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

for (<*.png>) {
    /^(..)-(\d+)\.png$/ or die $!;
    my $square = $1;
    $square = $squares{$square};
    my $square_row = int($square/7);
    my $square_col = $square%7;
    my $part = $2;
    my $part_row = int($part/16);
    my $part_col = $part%16;
    
    my $out_col = $square_col*16+$part_col;
    my $out_row = $square_row*16+$part_row;
    print "$_ $square_row $square_col $part_row $part_col : $out_col x $out_row\n";
    system("cp $_ $out_col.$out_row.png");
}
