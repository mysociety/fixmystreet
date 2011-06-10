package FixMyStreet::App::Controller::Tilma;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use LWP::UserAgent;

=head1 NAME

FixMyStreet::App::Controller::Tilma - Tilma proxy

=head1 DESCRIPTION

A tilma proxy - only intended to be used during dev. In production the webserver should do this proxying.

=head1 METHODS

=head2 default

Proxy everything through to the tilma servers.

=cut

sub default : Path {
    my ( $self, $c ) = @_;

    my $path = $c->req->uri->path_query;
    $path =~ s{/tilma/}{};

    my $tilma_uri = URI->new("http://tilma.mysociety.org/$path");

    my $tilma_res = LWP::UserAgent->new->get($tilma_uri);

    if ( $tilma_res->is_success ) {
        $c->res->content_type( $tilma_res->content_type );
        $c->res->body( $tilma_res->content );
    }
    else {
        die sprintf "Error getting %s: %s", $tilma_uri, $tilma_res->message;
    }
}

__PACKAGE__->meta->make_immutable;

1;
