package FixMyStreet::App::Form::Waste::Garden::Modify;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Modify::Shared';

# Inherits pages unaltered:
# intro
# summary
# done

has_page alter => alter();

sub alter {
    my %defaults
        = FixMyStreet::App::Form::Waste::Garden::Modify::Shared::alter();

    push @{ $defaults{fields} }, qw/name phone email/;

    $defaults{field_ignore_list} = sub {
        my $page = shift;
        return [ 'phone', 'email' ] unless $page->form->c->stash->{is_staff};
        return [];
    };

    return %defaults;
}

with 'FixMyStreet::App::Form::Waste::AboutYou';

1;
