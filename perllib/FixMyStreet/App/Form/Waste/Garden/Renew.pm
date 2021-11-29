package FixMyStreet::App::Form::Waste::Garden::Renew;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

my %intro_fields = (
    title => 'Renew your green garden waste subscription',
    template => 'waste/garden/renew.html',
    fields => ['current_bins', 'bins_wanted', 'payment_method', 'billing_differ', 'billing_address', 'name', 'phone', 'email', 'continue_review'],
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        $c->stash->{per_bin_cost} = $c->cobrand->garden_waste_cost;
        my $bins_wanted = $c->get_param('bins_wanted') || $form->saved_data->{bins_wanted} || $c->stash->{garden_form_data}->{bins};
        $c->stash->{payment} = $c->cobrand->garden_waste_cost( $bins_wanted ) / 100;
        return {
            current_bins => { default => $c->stash->{garden_form_data}->{bins} },
            bins_wanted => { default => $c->stash->{garden_form_data}->{bins} },
            name => { default => $c->stash->{is_staff} ? '' : $c->user->name },
            email => { default => $c->stash->{is_staff} ? '' : $c->user->email },
            phone => { default => $c->stash->{is_staff} ? '' : $c->user->phone },
        };
    },
    next => 'summary',
);

my %intro_fields_staff = (
    %intro_fields,
    ( fields => ['current_bins', 'bins_wanted', 'name', 'phone', 'email', 'continue_review'] )
);

has_page intro => ( %intro_fields );

has_page intro_staff => ( %intro_fields_staff );

has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Renew your green garden waste subscription',
    template => 'waste/garden/renew_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $form->saved_data;
        my $bins_wanted = $data->{bins_wanted};

        my $total = $c->cobrand->garden_waste_cost( $bins_wanted);

        my $orig_sub = $c->stash->{orig_sub};
        if ( $orig_sub ) {
            $data->{billing_address} = $orig_sub->get_extra_field_value('billing_address');
        }
        $data->{billing_address} ||= $c->stash->{property}{address};
        $data->{display_total} = $total / 100;

        unless ( $c->stash->{is_staff} ) {
            $data->{name} ||= $c->user->name;
            $data->{email} = $c->user->email;
            $data->{phone} ||= $c->user->phone;
        }
        return {};
    },
    finished => sub {
        return $_[0]->wizard_finished('process_garden_renew');
    },
    next => 'done',
);

has_page done => (
    title => 'Subscription renewed',
    template => 'waste/garden/renewed.html',
);

has_field current_bins => (
    type => 'Integer',
    label => 'Number of bins currently on site',
    tags => { number => 1 },
    required => 1,
    disabled => 1,
    range_start => 1,
    range_end => 6,
);

has_field bins_wanted => (
    type => 'Integer',
    label => 'Number of bins to be emptied (including bins already on site)',
    tags => { number => 1 },
    required => 1,
    range_start => 1,
    range_end => 6,
    tags => {
        hint => 'We will deliver, or remove, bins if this is different from the number of bins already on the property',
    }
);

with 'FixMyStreet::App::Form::Waste::Billing';

has_field tandc => (
    type => 'Checkbox',
    required => 1,
    label => 'Terms and conditions',
    option_label => FixMyStreet::Template::SafeString->new(
        'I agree to the <a href="/about/garden_terms" target="_blank">terms and conditions</a>',
    ),
);

has_field continue_review => (
    type => 'Submit',
    value => 'Review subscription',
    element_attr => { class => 'govuk-button' },
);

has_field submit => (
    type => 'Submit',
    value => 'Continue to payment',
    element_attr => { class => 'govuk-button' },
    order => 999,
);

sub validate {
    my $self = shift;
    my $max_bins = $self->{c}->stash->{garden_form_data}->{max_bins};
    unless ( $self->field('bins_wanted')->is_inactive ) {
        my $total = $self->field('bins_wanted')->value;
        $self->add_form_error('The total number of bins cannot exceed ' . $max_bins)
            if $total > $max_bins;

        $self->add_form_error('The total number of bins must be at least 1')
            if $total == 0;
    }
}

1;
