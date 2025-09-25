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
                # store Agile user details behind the scenes
                my $ref = $form->field('customer_reference')->value;
                my $current_subscription
                    = $form->c->cobrand->garden_current_subscription;

                if ( $ref eq $current_subscription->{customer_external_ref} ) {
                    $form->saved_data->{name}
                        = $current_subscription->{customer_first_name} . ' '
                        . $current_subscription->{customer_last_name};

                    $form->saved_data->{email}
                        = $current_subscription->{customer_email};
                    $form->saved_data->{phone}
                        = $current_subscription->{customer_phone};

                    return $args{next_page_if_verified};

                } else {
                    $form->c->stash->{error_customer_external_ref} = 1;
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
        intro => 'garden/verify/about_you.html',
        fields => [
            'first_name', 'last_name',
            'phone',      'email',
            $args{continue_field}
        ],
        title => 'About you',
        next => sub {
            my $form = $_[2];

            my $first_name = $form->field('first_name')->value;
            my $last_name = $form->field('last_name')->value;

            my $current_subscription
                = $form->c->cobrand->garden_current_subscription;

            my $name_verified
                = $first_name eq $current_subscription->{customer_first_name}
                && $last_name eq $current_subscription->{customer_last_name};

            if ($name_verified) {
                $form->saved_data->{name} = $first_name . ' ' . $last_name;
                return $args{next_page};

            } elsif ( $form->isa('FixMyStreet::App::Form::Waste::Garden::Renew::Bexley') ) {
                # Can continue renewal flow, but because not verified, do not
                # use current subscription details; instead set renewal up as
                # new subscription
                $form->saved_data->{name} = $first_name . ' ' . $last_name;

                $form->saved_data->{renew_as_new_subscription} = 1;

                return $args{next_page};

            } else {
                return 'verify_failed';

            }

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

sub verify_failed {
    return (
        template => 'waste/garden/verify_failed.html',
    );
}

1;
