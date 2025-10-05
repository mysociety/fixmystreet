package FixMyStreet::App::Form::Waste::Request::Merton;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

my %CONTAINERS_NO_ADDITIONAL = (
    2 => 'refuse_180',
    3 => 'refuse_240',
    4 => 'refuse_360',

    39 => 'garden_240',
    37 => 'garden_140',
);

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    intro => 'about_you.html',
    title => 'About you',
    next => 'summary',
    post_process => sub {
        my $form = shift;
        my $data = $form->saved_data;
        my $c = $form->c;

        my @services = grep { /^container-\d/ && $data->{$_} } sort keys %$data;
        my $total = 0;
        foreach (@services) {
            my ($id) = /container-(.*)/;
            my $quantity = $data->{"quantity-$id"} or next;
            if (my $cost = $c->cobrand->request_cost($id)) {
                $total += $cost * $quantity;
            }
        }
        $data->{payment} = $total if $total;
    },
);

has_page replacement => (
    fields => ['request_reason', 'request_reason_text', 'continue'],
    title => 'Reason for request',
    next => 'about_you',
    field_ignore_list => sub {
        my $page = shift;
        if (!$page->form->{c}->stash->{is_staff}) {
            return ['request_reason_text'];
        } else {
            return [];
        };
    },
);

has_field request_reason => (
    required => 1,
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Why do you need a replacement container?',
);

has_field request_reason_text => (
    required => 0,
    type => 'Text',
    widget => 'Textarea',
    label => 'Additional details',
    tags => { hint => 'Please enter any additional details that will help us with the request' },
);

sub options_request_reason {
    my $form = shift;
    my @options = (
        { value => 'new_build', label => 'I am a new resident without a container' },
        { value => 'damaged', label => 'Damaged' },
        { value => 'missing', label => 'Missing' },
    );
    my $data = $form->saved_data;
    my $only_refuse_or_garden = 1;
    my @services = grep { /^container-\d/ && $data->{$_} } sort keys %$data;
    foreach (@services) {
        my ($id) = /container-(.*)/;
        if (!$CONTAINERS_NO_ADDITIONAL{$id}) {
            $only_refuse_or_garden = 0;
            last;
        }
    }

    push @options,
        { value => 'more', label => 'I need an additional container/bin' }
        unless $only_refuse_or_garden;

    return @options;
}

has_page summary => (
    fields => ['submit', 'payment_method', 'payment_explanation', 'cheque_reference'],
    title => 'Submit container request',
    template => 'waste/summary_request.html',
    finished => sub {
        return $_[0]->wizard_finished('process_request_data');
    },
    # For payments, updating the submit button
    update_field_list => sub {
        my $form = shift;
        my $data = $form->saved_data;
        if ($data->{payment}) {
            return { submit => { value => 'Continue to payment' } };
        }
        return {};
    },
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;
        my $data = $page->form->saved_data;
        if (!$c->stash->{is_staff} || !$data->{payment}) {
            return ['payment_method', 'cheque_reference', 'payment_explanation'];
        }
        return ['cheque_reference'];
    },
    next => 'done',
);

with 'FixMyStreet::App::Form::Waste::Billing';

1;
