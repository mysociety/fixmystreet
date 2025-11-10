=head1 NAME

FixMyStreet::Cobrand::Whatever - code specific to the Whatever cobrand

=head1 SYNOPSIS

Rutland is a unitary authority, with a Salesforce backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Melton;
use parent 'FixMyStreet::Cobrand::Bromley';

use strict;
use warnings;

sub council_area_id { return 2498; }
sub council_area { return 'Melton'; }
sub council_name { return 'Melton Borough Council'; }
sub council_url { return 'melton'; }

sub asset_moniker { 'biffa' }

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker ),
        FixMyStreet->path_to( 'templates/web/biffa' ),
        FixMyStreet->path_to( 'templates/web/fixmystreet-uk-councils' ),
    ];
}

sub path_to_email_templates {
    my ( $self, $lang_code ) = @_;
    return [
        FixMyStreet->path_to( 'templates', 'email', $self->moniker ),
        FixMyStreet->path_to( 'templates', 'email', 'biffa' ),
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet-uk-councils' ),
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com' ),
    ];
}

1;
