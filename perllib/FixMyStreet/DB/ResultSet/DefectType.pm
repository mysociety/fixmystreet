package FixMyStreet::DB::ResultSet::DefectType;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub for_bodies {
    my ($rs, $bodies, $category) = @_;
    my $attrs = {
        'me.body_id' => $bodies,
    };
    if ($category) {
        $attrs->{'contact.category'} = [ $category, undef ];
    }
    $rs->search($attrs, {
        order_by => 'name',
        join => { 'contact_defect_types' => 'contact' },
        distinct => 1,
    });
}

1;
