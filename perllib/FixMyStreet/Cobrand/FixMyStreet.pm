package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::Default';

# FixMyStreet should return all cobrands
sub restriction {
    return {};
}

sub get_council_sender {
    my ( $self, $area_id, $area_info ) = shift;

    my $sender_conf = mySociety::Config::get( 'SENDERS' );
    return $sender_conf->{ $council } if exists $sender_conf->{ $council };

    return 'London' if $area_info->{type} eq 'LBO';

    return 'Open311' if FixMyStreet::App->model("DB::Open311conf")->search( { area_id => $council, endpoint => { '!=', '' } } )->first;

    return 'Email';
}

1;

