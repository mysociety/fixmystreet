package FixMyStreet::App::Form::Waste::Garden::Verify::Bexley;

use HTML::FormHandler::Moose::Role;

sub customer_reference {
    my %args = @_;

    return (
        fields =>
            [ 'has_reference', 'customer_reference', $args{continue_field} ],
        title => 'Please enter your customer reference number',
        next => sub {
            my $form = $_[2];

            if ( $form->field('has_reference')->value eq 'No' ) {
                return 'about_you';

            } else {
                # If correct customer reference provided, skip about_you and
                # store user details behind the scenes

                # TODO Email & phone?

                my $ref = $form->field('customer_reference')->value;
                my $current_subscription
                    = $form->c->cobrand->garden_current_subscription;

                if ( $ref eq $current_subscription->{customer_external_ref} ) {
                    $form->saved_data->{name}
                        = $current_subscription->{customer_first_name} . ' '
                        . $current_subscription->{customer_last_name};

                    return 'alter'; # TODO Handle for the other forms

                } else {
                    # TODO Message saying customer ref does not match
                    return 'about_you';

                }

            }

        },
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

# Create a dedicated page for entering personal details
sub about_you {
    my %args = @_;

    return (
        fields => [
            'first_name', 'last_name',
            'phone',      'email',
            $args{continue_field}
        ],
        title => 'About you',
        next => $args{next_page},
        pre_finished => sub {
            my $form = shift;
            $form->saved_data->{name}
                = $form->field('first_name')->value . ' '
                . $form->field('last_name')->value;
        },
    );
}

has_field first_name => (
    type => 'Text',
    label => 'First name',
    required => 1,
    messages => {
        required => 'Your first name is required',
    },
    order => 1,
);

has_field last_name => (
    type => 'Text',
    label => 'Last name',
    required => 1,
    messages => {
        required => 'Your last name is required',
    },
    order => 2,
);

with 'FixMyStreet::App::Form::Waste::AboutYou::Shared';

# sub validate_customer_reference {
#     my ( $form, $field ) = @_;

#     return 1 if $form->
# }

1;
