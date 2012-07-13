package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';

# FixMyStreet should return all cobrands
sub restriction {
    return {};
}

sub admin_base_url {
    return 'https://secure.mysociety.org/admin/bci/';
}

sub all_reports_style { return 'detailed'; }

sub allow_crosssell_adverts { return 1; }

1;

