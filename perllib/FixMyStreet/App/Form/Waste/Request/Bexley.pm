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
);

has_page letterbox_location => (
    fields => ['letterbox_location', 'continue'],
    title => 'Letterbox location',
    next => 'about_you',
);

has_field letterbox_location => (
    type => 'Select',
    widget => 'RadioGroup',
    required => 1,
    label => 'Where is your letterbox?',
);

has_page summary => (
    fields => ['declaration', 'submit'],
    title => 'Submit bin request',
    template => 'waste/summary_request.html',
    finished => sub {
        return $_[0]->wizard_finished('process_request_data');
    },
    next => 'done',
);

has_field declaration => (
    type => 'Checkbox',
    label => label_declaration(),
    option_label => 'I confirm I have read and understood the above statements',
    required => 1,
    tags => { safe => 'label' },
    messages => { required => 'Please read and accept the declaration' },
);

has_field submit => (
    type => 'Submit',
    value => 'Request bin delivery or removal',
    element_attr => { class => 'govuk-button' },
    order => 999,
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

sub options_letterbox_location {
    my $form = shift;

    my @options = (
        'At the front',
        'At the rear',
        'At the side',
        'On the first floor balcony',
        'Communal entrance',
    );
    return map { { label => $_, value => $_ } } @options;
}

sub label_declaration {
    my $text = <<HTML;
<div class="govuk-summary-list__key">Declaration</div>
<div>
By continuing with your request:
<br>
<ul>
<li>I agree that containers will only be used for the storage of waste and recycling for collection and will not be used for any other purposes</li>
<li>I understand that all waste and recycling containers remain the property of the London Borough of Bexley</li>
<li>I understand that if I have more than the permitted number of containers or misuse containers they may be removed from my property without prior notice</li>
<li>I understand that I will not necessarily receive brand-new waste containers. Where second-hand containers are delivered they will be clean and undamaged, but may have markings from their previous use</li>
</ul>
</div>
HTML
    return $text;
}

1;
