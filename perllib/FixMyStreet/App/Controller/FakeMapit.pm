package FixMyStreet::App::Controller::FakeMapit;
use Moose;
use namespace::autoclean;
use JSON::MaybeXS;
use LWP::Simple;

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

# The user should have the web server proxying this,
# but for development we can also do it on the server.
sub proxy : Path('/mapit') {
    my ($self, $c) = @_;
    (my $path = $c->req->uri->path_query) =~ s{^/mapit/}{};
    my $url = FixMyStreet->config('MAPIT_URL') . $path;
    my $kml = LWP::Simple::get($url);
    $c->response->body($kml);
}

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

