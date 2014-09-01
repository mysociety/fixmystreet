package FixMyStreet::Cobrand::MakeMyIsland;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub site_title { return 'MakeMyIsland'; }

sub language_domain { return 'MakeMyIsland'; }

sub country {
    return 'MV';
}

sub users_can_hide {
  return 1;
}

1;

