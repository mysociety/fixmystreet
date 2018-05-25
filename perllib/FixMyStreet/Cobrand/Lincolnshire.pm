package FixMyStreet::Cobrand::Lincolnshire;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;

sub council_area_id { return 2232; }
sub council_area { return 'Lincolnshire'; }
sub council_name { return 'Lincolnshire County Council'; }
sub council_url { return 'lincolnshire'; }
sub is_two_tier { 1 }

sub enable_category_groups { 1 }

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

    $row->set_extra_fields(@$extra);
}

1;
