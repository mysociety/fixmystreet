package FixMyStreet::App::Form::Waste::Request::Bexley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

has_field category_delivery => (
    type => 'Hidden',
    default => 'Request new container',
);

has_field category_removal => (
    type => 'Hidden',
    default => 'Request container removal',
);

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

has_page request_reason => (
    fields => ['request_reason', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
);

has_field request_reason => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Why do you need new bins?',
    messages => { required => 'Please select a reason' },
);

sub options_request_reason {
    my $form = shift;

    my @options = (
        'My existing bin is too small or big',
        'My existing bin is damaged',
        'My existing bin has gone missing',
        'I have moved into a new development',
        'Bins are no longer required',
    );
    return map { { label => $_, value => $_ } } @options;
}

sub validate {
    my $self = shift;

    if ( $self->page_name eq 'request' || $self->page_name eq 'request_removal' ) {
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
