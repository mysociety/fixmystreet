package Catalyst::Plugin::Compress::Gzip;
use strict;
use warnings;
use MRO::Compat;

use Compress::Zlib ();

sub finalize_headers {
    my $c = shift;

    if ( $c->response->content_encoding ) {
        return $c->next::method(@_);
    }

    unless ( $c->response->body ) {
        return $c->next::method(@_);
    }

    unless ( $c->response->status == 200 ) {
        return $c->next::method(@_);
    }

    unless ( $c->response->content_type =~ /^text|xml$|javascript$/ ) {
        return $c->next::method(@_);
    }

    my $accept = $c->request->header('Accept-Encoding') || '';

    unless ( index( $accept, "gzip" ) >= 0 ) {
        return $c->next::method(@_);
    }


   my $body = $c->response->body;
   eval { local $/; $body = <$body> } if ref $body;
   die "Response body is an unsupported kind of reference" if ref $body;

    $c->response->body( Compress::Zlib::memGzip( $body ) );
    $c->response->content_length( length( $c->response->body ) );
    $c->response->content_encoding('gzip');
    $c->response->headers->push_header( 'Vary', 'Accept-Encoding' );

    $c->next::method(@_);
}

1;

__END__

=head1 NAME

Catalyst::Plugin::Compress::Gzip - Gzip response

=head1 SYNOPSIS

    use Catalyst qw[Compress::Gzip];


=head1 DESCRIPTION

Gzip compress response if client supports it. Changed from CPAN version to
overload finalize_headers, rather than finalize.

=head1 METHODS

=head2 finalize_headers

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Christian Hansen, C<ch@ngmedia.com>
Matthew Somerville.

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut
