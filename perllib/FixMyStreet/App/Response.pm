# This package exists to try and work around a big bug in Edge:
# https://developer.microsoft.com/en-us/microsoft-edge/platform/issues/8572187/

package FixMyStreet::App::Response;
use Moose;
extends 'Catalyst::Response';

around 'redirect' => sub {
    my $orig = shift;
    my $self = shift;
    my ($location, $status) = @_;

    return $self->$orig() unless @_;  # getter

    my $agent = $self->_context->request->user_agent;
    return $self->$orig(@_) unless $agent =~ /Edge\/14/;  # Only care about Edge

    # Instead of a redirect, output HTML that redirects
    $self->body(<<END
<meta http-equiv="refresh" content="0; url=$location">
Please follow this link: <a href="$location">$location</a>
END
    );
    return $location;
};

1;
