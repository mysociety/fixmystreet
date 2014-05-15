package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';

use constant COUNCIL_ID_BROMLEY => 2482;

# FixMyStreet should return all cobrands
sub restriction {
    return {};
}

sub admin_base_url {
    return 'https://secure.mysociety.org/admin/bci';
}

sub title_list {
    my $self = shift;
    my $areas = shift;
    my $first_area = ( values %$areas )[0];

    return ["MR", "MISS", "MRS", "MS", "DR"] if $first_area->{id} eq COUNCIL_ID_BROMLEY;
    return undef;
}

sub extra_contact_validation {
    my $self = shift;
    my $c = shift;

    my %errors;

    $c->stash->{dest} = $c->req->param('dest');

    $errors{dest} = "Please enter who your message is for"
        unless $c->req->param('dest');

    if ( $c->req->param('dest') eq 'council' || $c->req->param('dest') eq 'update' ) {
        $errors{not_for_us} = 1;
    }

    return %errors;
}

1;

