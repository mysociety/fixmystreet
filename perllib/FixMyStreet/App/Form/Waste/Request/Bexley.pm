package FixMyStreet::App::Form::Waste::Request::Bexley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

# Shown as first page if property able to order Green Wheelie Bins
has_page household_size => (
    title => 'Household size',
    fields => [ 'household_size', 'continue' ],
    next => 'request',
);

has_field household_size => (
    type => 'Select',
    widget => 'RadioGroup',
    label   => 'How many people live at the property?',
    options => [
        map {
            label     => $_,
            value     => $_,
        },
        ( 1..4, '5 or more' )
    ],
    required => 1,
    messages => { required => 'Please select an amount' },
);

sub validate {
    my $self = shift;

    if ( $self->page_name eq 'request' ) {
        # Get all checkboxes and make sure at least one selected
        my $bin_count = 0;
        for my $field_name ( @{ $self->current_page->fields } ) {
            my $field = $self->field($field_name);

            if ( $field->type eq 'Checkbox' && $field->value ) {
                $bin_count++;
            }
        }

        if ( !$bin_count ) {
            $self->add_form_error('Please specify what you need');
        }
    }

    # Skip validate() in Form/Waste/Request.pm
    FixMyStreet::App::Form::Waste::validate($self);
}

1;
