package FixMyStreet::Cobrand::MakeMyIsland;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub site_title { return 'MakeMyIsland'; }

sub language_domain { return 'MakeMyIsland'; }

sub country {
    return 'MV';
}

# allows Fonadhoo Island Council staff to hide reports
# currently there's only one council, id=1
sub council_id {
  return  1;
}

sub users_can_hide {
  return 1;
}

1;

