package FixMyStreet::Cobrand::Whitelabel;
use base 'FixMyStreet::Cobrand::UKCouncils';

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker ),
        FixMyStreet->path_to( 'templates/web/whitelabel' ),
        FixMyStreet->path_to( 'templates/web/fixmystreet-uk-councils' ),
    ];
}

1;
