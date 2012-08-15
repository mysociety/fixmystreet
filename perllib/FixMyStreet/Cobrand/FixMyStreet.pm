package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';

# FixMyStreet should return all cobrands
sub restriction {
    return {};
}

sub admin_base_url {
    return 'https://secure.mysociety.org/admin/bci/';
}

1;

