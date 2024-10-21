package FixMyStreet::App::Form::Waste::Request::Bexley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

has_page replacement => (
    fields => ['request_reason', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
);

has_field request_reason => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Why do you need new bins?',
);

# TODO Different for MDR-SACK properties
sub options_request_reason {
    my $form = shift;
    my @options = (
        'My existing bin is too small or big',
        'My existing bin is damaged',
        'My existing bin has gone missing',
        'I have moved into a new development',
    );
    return map { { label => $_, value => $_ } } @options;
}

# TODO
# Number of residents?
# Check for existing requests for a given container.
# Message to user if failed delivery, direct them to enquiry form.

1;
