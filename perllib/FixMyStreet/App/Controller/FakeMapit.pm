package FixMyStreet::App::Controller::FakeMapit;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::FakeMapit - Catalyst Controller

=head1 DESCRIPTION

A controller to fake mapit when we don't have it. If you set MAPIT_URL to
.../fakemapit/ it should all just work, with a mapit that assumes the whole
world is one area, with ID 0 and name "Default Area".

=head1 METHODS

=cut

my $area = { "name" => "Default Area", "type" => "ZZZ", "id" => 0 };

sub output : Private {
    my ( $self, $c, $data ) = @_;
    my $body = JSON->new->utf8(1)->encode( $data );
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body( $body );
}

sub point : Local {
    my ( $self, $c ) = @_;
    $c->detach( 'output', [ { 0 => $area } ] );
}

sub area : Local {
    my ( $self, $c ) = @_;
    $c->detach( 'output', [ $area ] );
}

sub areas : Local {
    my ( $self, $c ) = @_;
    $c->detach( 'output', [ { 0 => $area } ] );
}

sub children : Path('area/0/children') : Args(0) {
    my ( $self, $c ) = @_;
    $c->detach( 'output', [ {} ] );
}

__PACKAGE__->meta->make_immutable;

1;

