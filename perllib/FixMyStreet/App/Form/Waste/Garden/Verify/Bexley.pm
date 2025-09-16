package FixMyStreet::App::Form::Waste::Garden::Verify::Bexley;

use HTML::FormHandler::Moose::Role;

sub customer_reference {
    my %args = @_;

    return (
        fields =>
            [ 'has_reference', 'customer_reference', $args{continue_field} ],
        title => 'Please enter your customer reference number',
# TODO If correct customer reference provided, skip about_you and store
# user details behind the scenes?
        next => 'about_you',
    );
}

has_field has_reference => (
    type     => 'Select',
    widget   => 'RadioGroup',
    label    => 'Do you have a customer reference number?',
    required => 1,
    options  => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No',  value => 'No' },
    ],
    order => 1,
);

has_field customer_reference => (
    type => 'Text',
    label => 'Customer reference number',
    required_when => { has_reference => 'Yes' },
    order => 2,
);

with 'FixMyStreet::App::Form::Waste::AboutYou';

# Create a dedicated page for entering personal details
sub about_you {
    my %args = @_;

    return (
        fields => [ 'name', 'phone', 'email', $args{continue_field} ],
        title => 'About you',
        next => $args{next_page},
    );
}

# Remove name, phone, email from a given page setup
sub remove_about_you_fields {
    my %defaults = @_;
    my @fields = grep { $_ !~ /^(name|phone|email)$/ } @{ $defaults{fields} };
    $defaults{fields} = \@fields;
    return %defaults;
}

1;
