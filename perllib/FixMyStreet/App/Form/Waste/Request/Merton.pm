package FixMyStreet::App::Form::Waste::Request::Merton;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Request';

my %CONTAINERS_NO_ADDITIONAL = (
    2 => 'refuse_240',
    3 => 'refuse_360',
    35 => 'refuse_180',

    26 => 'garden_240',
    27 => 'garden_140',
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
        }
    }

    push @options,
        { value => 'more', label => 'I need an additional container/bin' }
        unless $only_refuse_or_garden;

    return @options;
}

1;
