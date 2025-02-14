package FixMyStreet::App::Form::Waste::Request::Peterborough;

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

sub options_request_reason {
    my $form = shift;
    my @options = (
        { label => 'Cracked bin', value => 'cracked', data_hide => '#request_reason-item-hint' },
        { label => 'Lost/stolen bin', value => 'lost_stolen', data_hide => '#request_reason-item-hint' },
        {
            label => 'New build',
            value => 'new_build',
            hint => 'To reduce the number of bins being stolen or damaged, bins must only be ordered within 2 weeks prior to your move in date.',
            hint_class => 'hidden-js',
            data_show => '#request_reason-item-hint',
        },
    );
    if ( $form->{c}->user && $form->{c}->user->from_body
         && $form->{c}->user->from_body->name eq 'Peterborough City Council' ) {
            push @options, { label => '(Other - PD STAFF)', value => 'other_staff', data_hide => '#request_reason-item-hint' };
    }
    return @options;
}

has_field extra_detail => (
    type => 'Text',
    widget => 'Textarea',
    label => 'Please supply any additional information.',
    maxlength => 1_000,
    messages => {
        text_maxlength => 'Please use 1000 characters or less for additional information.',
    },
);

# The bits below are necessary to use "bin" instead of "container" in the UI,
# that's all.

has_page summary => (
    fields => ['extra_detail', 'submit'],
    title => 'Submit bin request',
    template => 'waste/summary_request.html',
    finished => sub {
        return $_[0]->wizard_finished('process_request_data');
    },
    next => 'done',
);

has_field submit => (
    type => 'Submit',
    value => 'Request new bins',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub default_submit {
    return shift->{c}->get_param("bags_only") ? "Request food bags" : "Request new bins";
}

1;
