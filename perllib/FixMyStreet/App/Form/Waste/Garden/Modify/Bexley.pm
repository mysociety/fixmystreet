package FixMyStreet::App::Form::Waste::Garden::Modify::Bexley;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Modify::Shared';

with 'FixMyStreet::App::Form::Waste::Garden::Verify::Bexley';

# Inherits pages from Shared:
# intro
# summary
# done

has_page customer_reference => (
    customer_reference(
        continue_field        => 'continue',
        next_page_if_verified => 'alter',
    )
);

has_page about_you =>
    ( about_you( continue_field => 'continue', next_page => 'alter' ) );

has_page verify_failed => ( verify_failed() );

has_page alter =>
    FixMyStreet::App::Form::Waste::Garden::Modify::Shared::alter();

sub validate {
    my $self = shift;

    unless ( $self->field('current_bins')->is_inactive ) {
        my $current = $self->field('current_bins')->value;
        my $wanted  = $self->field('bins_wanted')->value;
        $self->add_form_error(
            'You need to change the number of bins.')
            if $wanted == $current;
    }

    $self->next::method();
}


1;
