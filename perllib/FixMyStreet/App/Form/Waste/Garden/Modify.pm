package FixMyStreet::App::Form::Waste::Garden::Modify;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste';

has_field is_staff => ( type => 'Hidden' );

has_page intro => (
    title => 'Modify your green garden waste subscription',
    template => 'waste/garden/modify_pick.html',
    fields => ['task', 'continue'],
    update_field_list => sub {
        my $form = shift;
        return {
            is_staff => { default => $form->{c}->stash->{is_staff} }
        };
    },
    next => sub { return $_[0]->{is_staff} ? 'alter_staff' : 'alter'; },
);

my %alter_fields = (
    title => 'Modify your green garden waste subscription',
    template => 'waste/garden/modify.html',
    fields => ['current_bins', 'bins_wanted', 'name', 'continue_review'],
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        my $data = $c->stash->{garden_form_data};
        $c->stash->{per_bin_cost} = $c->cobrand->garden_waste_cost;
        my $current_bins = $form->saved_data->{current_bins} || $data->{bins};
        my $bins_wanted = $c->get_param('bins_wanted') || $form->saved_data->{bins_wanted} || $data->{bins};
        $c->stash->{cost_per_year} = $c->cobrand->garden_waste_cost( $bins_wanted ) / 100;
        $c->stash->{new_bin_count} = 0;
        $c->stash->{pro_rata} = 0;
        if ( $bins_wanted > $current_bins ) {
            $c->stash->{new_bin_count} = $bins_wanted - $current_bins;
            $c->stash->{pro_rata} = $c->cobrand->waste_get_pro_rata_cost( $c->stash->{new_bin_count}, $c->stash->{garden_form_data}->{end_date}) / 100;
        }
        return {
            name => { default => $c->stash->{is_staff} ? '' : $c->user->name },
            current_bins => { default => $data->{bins} },
            bins_wanted => { default => $data->{bins} },
        };
    },
    next => 'summary',
);

my %alter_fields_staff = (
    %alter_fields,
    ( fields => ['current_bins', 'bins_wanted', 'name', 'phone', 'email', 'continue_review'] ),
);

has_page alter => ( %alter_fields );

has_page alter_staff => ( %alter_fields_staff );

with 'FixMyStreet::App::Form::Waste::AboutYou';

has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Modify your green garden waste subscription',
    template => 'waste/garden/modify_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $form->saved_data;
        my $new_bins = $data->{bins_wanted} - $data->{current_bins};
        my $pro_rata = $c->cobrand->waste_get_pro_rata_cost( $new_bins, $c->stash->{garden_form_data}->{end_date});
        my $total = $c->cobrand->garden_waste_cost($data->{bins_wanted});

        $data->{payment_method} = $c->stash->{garden_form_data}->{payment_method};
        $data->{billing_address} = $c->stash->{garden_form_data}->{billing_address} || $c->stash->{property}{address};
        $data->{display_pro_rata} = $pro_rata < 0 ? 0 : $pro_rata / 100;
        $data->{display_total} = $total / 100;

        unless ( $c->stash->{is_staff} ) {
            $data->{name} ||= $c->user->name;
            $data->{email} = $c->user->email;
            $data->{phone} ||= $c->user->phone;
        }
        my $button_text = 'Continue to payment';
        if ( $data->{payment_method} eq 'credit_card' ) {
            if ( $new_bins <= 0 ) {
                $button_text = 'Confirm changes';
            }
        } elsif ( $data->{payment_method} eq 'direct_debit' ) {
            $button_text = 'Amend Direct Debit';
        }
        return {
            submit => { default => $button_text },
        };
    },
    finished => sub {
        return $_[0]->wizard_finished('process_garden_modification');
    },
    next => 'done',
);

has_page done => (
    title => 'Subscription amended',
    template => 'waste/garden/amended.html',
);

has_field task => (
    type => 'Select',
    label => 'What do you want to do?',
    required => 1,
    widget => 'RadioGroup',
    options => [
        { value => 'modify', label => 'Increase or reduce the number of bins in your subscription' },
        { value => 'cancel', label => 'Cancel your green garden waste subscription' },
    ],
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
    label => 'How many bins to be emptied (including bins already on site)',
    tags => { number => 1 },
    required => 1,
    range_start => 1,
    range_end => 6,
    tags => {
        hint => 'We will deliver, or remove, bins if this is different from the number of bins already on the property',
    }
);

has_field tandc => (
    type => 'Checkbox',
    required => 1,
    label => 'Terms and conditions',
    option_label => FixMyStreet::Template::SafeString->new(
        'I agree to the <a href="/about/garden_terms" target="_blank">terms and conditions</a>',
    ),
);

has_field continue => (
    type => 'Submit',
    value => 'Continue',
    element_attr => { class => 'govuk-button' },
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

1;
