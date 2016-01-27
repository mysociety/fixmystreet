package FixMyStreet::App::Controller::FakeMapit;
use Moose;
use namespace::autoclean;
use JSON::MaybeXS;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::FakeMapit - Catalyst Controller

=head1 DESCRIPTION

A controller to fake mapit when we don't have it. If you set MAPIT_URL to
.../fakemapit/ it should all just work, with a mapit that assumes the whole
world is one area, with ID 161 and name "Everywhere".

=head1 METHODS

=cut

my $area = { "name" => "Everywhere", "type" => "ZZZ", "id" => 161 };

sub output : Private {
    my ( $self, $c, $data ) = @_;
    my $body = encode_json($data);
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body( $body );
}

sub point : Local {
    my ( $self, $c ) = @_;
    $c->detach( 'output', [ { 161 => $area } ] );
}

sub area : Local {
    my ( $self, $c ) = @_;
    $c->detach( 'output', [ $area ] );
}

sub areas : Local {
    my ( $self, $c ) = @_;
    $c->detach( 'output', [ { 161 => $area } ] );
}

sub children : Path('area/161/children') : Args(0) {
    my ( $self, $c ) = @_;
    $c->detach( 'output', [ {} ] );
}

__PACKAGE__->meta->make_immutable;

1;

