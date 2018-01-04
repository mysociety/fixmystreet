package FixMyStreet::App::Engine;

use Moose;
extends 'Catalyst::Engine';

use CGI::Cookie;
use utf8;

use namespace::clean -except => 'meta';

=head1 NAME

FixMyStreet::App::Engine - Catalyst Engine wrapper

=head1 SYNOPSIS

See L<Catalyst::Engine>.

=head1 METHODS

=head2 $self->finalize_cookies($c)

Create CGI::Cookie objects from C<< $c->res->cookies >>, and set them as
response headers. Adds a C<samesite=lax> part.

=cut

sub finalize_cookies {
    my ( $self, $c ) = @_;

    my @cookies;
    my $response = $c->response;

    foreach my $name (keys %{ $response->cookies }) {

        my $val = $response->cookies->{$name};

        my $cookie = (
            blessed($val)
            ? $val
            : CGI::Cookie->new(
                -name    => $name,
                -value   => $val->{value},
                -expires => $val->{expires},
                -domain  => $val->{domain},
                -path    => $val->{path},
                -secure  => $val->{secure} || 0,
                -httponly => $val->{httponly} || 0,
                -samesite => 'Lax',
            )
        );
        if (!defined $cookie) {
            $c->log->warn("undef passed in '$name' cookie value - not setting cookie")
                if $c->debug;
            next;
        }

        push @cookies, $cookie->as_string;
    }

    for my $cookie (@cookies) {
        $response->headers->push_header( 'Set-Cookie' => $cookie );
    }
}

__PACKAGE__->meta->make_immutable;

1;
