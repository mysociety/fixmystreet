package FixMyStreet::Cobrand::Brent;
use parent 'FixMyStreet::Cobrand::UKCouncils';

sub council_area_id { return 2488; }
sub council_area { return 'Brent'; }
sub council_name { return 'Brent Council'; }
sub council_url { return 'brent'; }

sub path_to_pin_icons {
    return '/cobrands/brent/images/';
}

sub admin_user_domain { 'brent.gov.uk' }

1;
