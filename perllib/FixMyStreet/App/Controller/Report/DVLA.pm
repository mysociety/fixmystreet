package FixMyStreet::App::Controller::Report::DVLA;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

use JSON::MaybeXS;
use LWP::UserAgent;

sub lookup : Path : Args(0) {
    my ($self, $c) = @_;

    my $reg = $c->req->body_params->{registration};
    $reg =~ s/[^a-z0-9]//gi;
    my $request = {
        registrationNumber => $reg,
    };

    my $ua = LWP::UserAgent->new;

    my $dvla = $c->cobrand->feature('dvla');
    $c->detach( '/page_error_404_not_found' ) unless $dvla;

    my $response = $ua->post(
        $dvla->{uri} . '/v1/vehicles',
        X_API_Key => $dvla->{key},
        Content_Type => 'application/json',
        Content => encode_json($request),
    );

    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($response->decoded_content);
}

1;
