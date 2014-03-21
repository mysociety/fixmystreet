package FixMyStreet::SendReport::Noop;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport'; }

# Always skip when using this method
sub should_skip {
    return 1;
}

1;
