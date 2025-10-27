package FixMyStreet::App::Form::Waste::Garden::Cancel;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Cancel::Shared';

# Inherits pages unaltered:
# done

has_page intro => intro();

sub intro {
    my %defaults
        = FixMyStreet::App::Form::Waste::Garden::Cancel::Shared::intro();

    push @{ $defaults{fields} }, qw/name phone email/;

    $defaults{field_ignore_list} = sub {
        my $page = shift;
        my $c = $page->form->c;
        my $ask_staff = $c->cobrand->call_hook('waste_cancel_asks_staff_for_user_details');
        my $staff = $c->stash->{is_staff};
        return ['name', 'phone', 'email'] unless $staff && $ask_staff;
        return [];
    };

    return %defaults;
}

has_field confirm => (
    type => 'Checkbox',
    option_label => 'I confirm I wish to cancel my subscription',
    required => 1,
    label => "Confirm",
    order => 998,
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

1;
