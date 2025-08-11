package FixMyStreet::App::Form::Waste::Bulky::Cancel;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_page intro => (
    title => 'Cancel your bulky collection',
    intro => 'bulky/cancel_intro.html',
    fields => ['name', 'phone', 'email', 'confirm', 'submit'],
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;
        my $ask_staff = $c->cobrand->call_hook('waste_cancel_asks_staff_for_user_details');
        my $staff = $c->stash->{is_staff};
        return ['name', 'phone', 'email'] unless $staff && $ask_staff;
        return [];
    },
    finished => sub {
        return $_[0]->wizard_finished('process_bulky_cancellation');
    },
    next => 'done',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page done => (
    title => 'Bulky collection cancelled',
    template => 'waste/bulky/booking_cancellation.html',
);

has_field confirm => (
    type => 'Checkbox',
    required => 1,
    label => "Confirm",
    build_option_label_method => sub {
        my $cobrand = $_[0]->form->{c}->cobrand;
        my $text = 'I confirm I wish to cancel my bulky collection';
        if ($cobrand->moniker eq 'kingston' || $cobrand->moniker eq 'sutton') {
            $text = 'I acknowledge that the collection fee is non-refundable and would like to cancel my bulky collection';
        } elsif ($cobrand->moniker eq 'bexley') {
            my $report = $_[0]->form->{c}->stash->{cancelling_booking};
            my $refund = sprintf( '%.2f',
                $report->get_extra_field_value('payment') / 100 );
            $text = <<"HERE";
I confirm I wish to cancel my bulky waste collection and receive a full refund of £$refund.
<br><br>
Funds will be returned to the card you used to pay for the booking. Please note that refunds can take up to 5 working days to process.
HERE
        }
        return FixMyStreet::Template::SafeString->new($text);
    },
);

has_field submit => (
    type => 'Submit',
    value => 'Cancel collection',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

1;
