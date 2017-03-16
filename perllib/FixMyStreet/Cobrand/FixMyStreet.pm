package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';

use mySociety::Random;

use constant COUNCIL_ID_BROMLEY => 2482;

# Special extra
sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web/fixmystreet.com' ),
    ];
}
sub path_to_email_templates {
    my ( $self, $lang_code ) = @_;
    return [
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com'),
    ];
}

sub add_response_headers {
    my $self = shift;
    my $csp_nonce = $self->{c}->stash->{csp_nonce} = unpack('h*', mySociety::Random::random_bytes(16, 1));
    $self->{c}->res->header('Content-Security-Policy', "script-src 'self' www.google-analytics.com www.googleadservices.com 'unsafe-inline' 'nonce-$csp_nonce'")
}

# FixMyStreet should return all cobrands
sub restriction {
    return {};
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

    # Don't care about dest if reporting abuse
    return () if $c->stash->{problem};

    my %errors;

    $c->stash->{dest} = $c->get_param('dest');

    $errors{dest} = "Please enter who your message is for"
        unless $c->get_param('dest');

    if ( $c->get_param('dest') eq 'council' || $c->get_param('dest') eq 'update' ) {
        $errors{not_for_us} = 1;
    }

    return %errors;
}

1;

