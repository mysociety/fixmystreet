package FixMyStreet::App::Form::Waste::Garden::Renew;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Renew::Shared';

# Inherits pages unaltered:
# discount
# summary
# done

has_page intro => intro();

sub intro {
    my %defaults
        = FixMyStreet::App::Form::Waste::Garden::Renew::Shared::intro();

    push @{ $defaults{fields} }, qw/name phone email/;

    return %defaults;
}

with 'FixMyStreet::App::Form::Waste::AboutYou';

1;
