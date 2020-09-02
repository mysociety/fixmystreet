package FixMyStreet::App::Form::Noise::UPRN;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';

use mySociety::PostcodeUtil qw(is_valid_postcode);

sub build_page_name_space { 'FixMyStreet::App::Form::Page' }

has '+field_name_space' => ( default => 'FixMyStreet::App::Form::Field' );

has cobrand => ( is => 'ro' );

has addresses => ( is => 'rw');

has_page postcode => (
    title => 'What is your address?',
    intro => 'postcode.html',
    form => 'FixMyStreet::App::Form::Noise::UPRN',
    next => 'address',
);

has_page source_known_postcode => (
    title => 'The source of the noise',
    next => 'source_known_address',
    form => 'FixMyStreet::App::Form::Noise::UPRN',
);

has_field postcode => (
    required => 1,
    type => 'Postcode',
    validate_method => sub {
        my $self = shift;
        return if $self->has_errors; # Called even if already failed
        my $data = [
            { value => 'house1', label => 'House 1' },
            { value => 'house2', label => 'House 2' },
            { value => 'house3', label => 'House 3' },
        ];
        if (!@$data) {
            $self->add_error('Sorry, we did not find any results for that postcode');
        }
        push @$data, { value => 'missing', label => 'I can’t find my address' };
        $self->form->addresses($data);
    },
    tags => { autofocus => 1 },
);

has_field go => (
    type => 'Submit',
    value => 'Find address',
    element_attr => { class => 'govuk-button' },
);

__PACKAGE__->meta->make_immutable;

1;
