package FixMyStreet::App::Form::Waste::Report;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

# First page has dynamic fields, so is set in code

has_page about_you => (
    fields => ['name', 'email', 'phone', 'continue'],
    title => 'About you',
    next => 'summary',
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page summary => (
    fields => ['submit', 'tandc'],
    title => 'Submit missed collection',
    template => 'waste/summary_report.html',
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;
        my $cobrand = $c->cobrand->moniker;
        if ($cobrand ne 'bexley') {
            return ['tandc'];
        }
    },
    finished => sub {
        return $_[0]->wizard_finished('process_report_data');
    },
    next => 'done',
);

has_field tandc => (
    type => 'Multiple',
    widget => 'CheckboxGroup',
    label => 'Terms and conditions',
    required => 1,
);

sub options_tandc {
    my $form = $_[0]->form;
    my $c = $form->c;
    my @options;
    my $label;
    if ($c->cobrand->moniker eq 'bexley') {
        $label = << 'HERE';
&bull; My rubbish or recycling was put out at the right place by 6am on my collection day.
<br>
&bull; My bin contains the correct types of rubbish and recycling and does not contain any hazardous materials.
<br>
&bull; My bin has not already been emptied and has not been re-filled following the scheduled collection.
<br>
&bull; I am aware that missed collections that are falsely reported will be cancelled and my bin will not be emptied.
HERE
    }
    $label = FixMyStreet::Template::SafeString->new($label);
    push @options,
        { label => $label, value => 1 };
    return @options;
}

has_page done => (
    title => 'Missed collection sent',
    template => 'waste/confirmation.html',
);

has_field category => (
    type => 'Hidden',
    default => 'Report missed collection'
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

has_field submit => (
    type => 'Submit',
    value => 'Report collection as missed',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub validate {
    my $self = shift;
    my $any = 0;

    # Bypass check for clinical form, because the user may not have a clinical
    # service, and if they do, it is guaranteed to be set as a hidden field
    unless ( $self->{c}->stash->{clinical} ) {
        foreach ($self->all_fields) {
            $any = 1 if $_->name =~ /^service-/ && ($_->value || $self->saved_data->{$_->name});
        }
        $self->add_form_error('Please specify what was missed')
            unless $any;
    }

    $self->next::method();
}

1;
