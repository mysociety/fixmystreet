package FixMyStreet::App::Form::Waste::UPRN;

use utf8;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

use mySociety::PostcodeUtil qw(is_valid_postcode);

has '+field_name_space' => ( default => 'FixMyStreet::App::Form::Field' );

has cobrand => ( is => 'ro', weak_ref => 1 );

has '+name' => ( default => 'uprn' );

has_field postcode => (
    required => 1,
    type => 'Postcode',
    validate_method => sub {
        my $self = shift;
        return if $self->has_errors; # Called even if already failed
        my $data = $self->form->cobrand->bin_addresses_for_postcode($self->value);
        if (!@$data) {
            my $error = 'Sorry, we did not find any results for that postcode';
            if ($self->form->cobrand->moniker eq 'peterborough') {
                $error = 'Unfortunately this postcode is not in Peterborough City Council’s local area. Please contact your local council.';
            }
            $self->add_error($error);
        }
        push @$data, { value => 'missing', label => 'I can’t find my address' };
        $self->value($data);
    },
    tags => { autofocus => 1 },
);

has_field go => (
    type => 'Submit',
    value => 'Go',
    element_attr => { class => 'govuk-button' },
);

__PACKAGE__->meta->make_immutable;

1;
