package FixMyStreet::App::Form::Waste::Garden::Modify::Shared;

use utf8;

use HTML::FormHandler::Moose;
use WasteWorks::Costs;

extends 'FixMyStreet::App::Form::Waste';

# intro page

has_page intro => (
    title => 'Change your garden waste subscription',
    template => 'waste/garden/modify_pick.html',
    fields => ['task', 'apply_discount', 'continue'],
    next => sub {
        my $form = $_[2];
        return $form->c->stash->{next_page} || 'alter';
    },
    field_ignore_list => sub {
        my $page = shift;
        my $c = $page->form->c;
        if (!($c->stash->{waste_features}->{ggw_discount_as_percent}) || !($c->stash->{is_staff})) {
            return ['apply_discount']
        }
    },
);

has_field task => (
    type => 'Select',
    label => 'What do you want to do?',
    required => 1,
    widget => 'RadioGroup',
    options_method => sub {
        my $self = shift;
        my $form = $self->form;
        my $c = $form->c;
        my @options;
        if ($c->cobrand->moniker eq 'kingston' || $c->cobrand->moniker eq 'sutton' || $c->cobrand->moniker eq 'brent' || $c->cobrand->moniker eq 'merton') {
            push @options, { value => 'modify', label => 'Increase the number of bins in your subscription' };
        } else {
            push @options, { value => 'modify', label => 'Increase or reduce the number of bins in your subscription' };
        }
        push @options, { value => 'cancel', label => 'Cancel your garden waste subscription' };
        return \@options;
    },
);

has_field apply_discount => (
    type => 'Checkbox',
    build_label_method => sub {
        my $self = shift;
        my $percent = $self->parent->{c}->stash->{waste_features}->{ggw_discount_as_percent};
        return "$percent" . '% Customer discount';
    },
    option_label => 'Check box if customer is entitled to a discount',
);

# alter page

has_page alter => alter();

sub alter {
    return (
        title => 'Change your garden waste subscription',
        template => 'waste/garden/modify.html',
        fields => ['current_bins', 'bins_wanted', 'continue_review'],
        update_field_list => sub {
            my $form = shift;
            my $c = $form->c;
            my $data = $c->stash->{garden_form_data};
            my $current_bins = $c->get_param('current_bins') || $form->saved_data->{current_bins} || $data->{bins};
            my $bins_wanted = $c->get_param('bins_wanted') || $form->saved_data->{bins_wanted} || $data->{bins};
            my $new_bins = $bins_wanted - $current_bins;

            my $edit_current_allowed = $c->cobrand->call_hook('waste_allow_current_bins_edit');
            my $costs = WasteWorks::Costs->new({
                cobrand => $c->cobrand,
                discount => $form->saved_data->{apply_discount},
                first_bin_discount => $c->cobrand->call_hook(garden_waste_first_bin_discount_applies => $data) || 0,
            });
            my $cost_pa = $costs->bins($bins_wanted);
            my $cost_now_admin = $costs->new_bin_admin_fee($new_bins);
            $c->stash->{cost_pa} = $cost_pa / 100;
            $c->stash->{cost_now_admin} = $cost_now_admin / 100;

            $c->stash->{new_bin_count} = 0;
            $c->stash->{pro_rata} = 0;
            if ($new_bins > 0) {
                $c->stash->{new_bin_count} = $new_bins;
                my $cost_pro_rata = $costs->pro_rata_cost($new_bins);
                $c->stash->{pro_rata} = ($cost_now_admin + $cost_pro_rata) / 100;
            }

            my $max_bins = $data->{max_bins};
            my %bin_params = ( default => $data->{bins}, range_end => $max_bins );
            return {
                name => { default => $c->stash->{is_staff} ? '' : $c->user->name },
                current_bins => { %bin_params, $edit_current_allowed ? (disabled=>0) : () },
                bins_wanted => { %bin_params },
            };
        },
        next => 'summary',
    );
}

has_field current_bins => (
    type => 'Integer',
    label => 'Number of bins currently on site',
    tags => { number => 1 },
    required => 1,
    disabled => 1,
    range_start => 1,
);

has_field bins_wanted => (
    type => 'Integer',
    label => 'How many bins to be emptied (including bins already on site)',
    tags => { number => 1 },
    required => 1,
    range_start => 1,
    tags => {
        hint => 'We will deliver, or remove, bins if this is different from the number of bins already on the property',
    }
);

# summary page

has_page summary => (
    fields => ['tandc', 'submit'],
    title => 'Change your garden waste subscription',
    template => 'waste/garden/modify_summary.html',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->{c};
        my $data = $form->saved_data;
        my $current_bins = $data->{current_bins};
        my $bin_count = $data->{bins_wanted};
        my $new_bins = $bin_count - $current_bins;

        # We need to make sure we have payment_method before we call
        # garden_waste_first_bin_discount_applies
        $data->{payment_method}
            = $c->stash->{garden_form_data}->{payment_method};
        my $costs = WasteWorks::Costs->new({
            cobrand => $c->cobrand,
            discount => $data->{apply_discount},
            first_bin_discount => $c->cobrand->call_hook(garden_waste_first_bin_discount_applies => $data) || 0,
        });
        my $pro_rata = $costs->pro_rata_cost($new_bins);
        my $cost_pa = $costs->bins($bin_count);
        my $cost_now_admin = $costs->new_bin_admin_fee($new_bins);
        my $total = $cost_pa;
        $pro_rata += $cost_now_admin;

        $data->{cost_now_admin} = $cost_now_admin / 100;
        $data->{display_pro_rata} = $pro_rata < 0 ? 0 : $pro_rata / 100;
        $data->{display_total} = $total / 100;

        unless ( $c->stash->{is_staff} ) {
            $data->{name} ||= $c->user->name;
            $data->{email} = $c->user->email;
            $data->{phone} ||= $c->user->phone;
        }
        my $button_text = 'Continue to payment';
        my $features = $form->{c}->cobrand->feature('waste_features');
        if ( $data->{payment_method} eq 'credit_card' || $data->{payment_method} eq 'csc' ) {
            if ( $new_bins <= 0 ) {
                $button_text = 'Confirm changes';
            }
        } elsif ( $data->{payment_method} eq 'direct_debit' ) {
            $button_text = 'Amend Direct Debit';
        }
        if ($c->stash->{is_staff} && $features->{text_for_waste_payment}) {
            $button_text =  $features->{text_for_waste_payment};
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

with 'FixMyStreet::App::Form::Waste::GardenTandC';

# done page

has_page done => (
    title => 'Subscription amended',
    template => 'waste/garden/amended.html',
);

# Buttons

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

sub validate {
    my $self = shift;
    my $cobrand = $self->{c}->cobrand->moniker;

    if ($cobrand eq 'kingston' || $cobrand eq 'sutton' || $cobrand eq 'brent'  || $cobrand eq 'merton') {
        unless ( $self->field('current_bins')->is_inactive ) {
            my $total = $self->field('bins_wanted')->value;
            my $current = $self->field('current_bins')->value;
            $self->add_form_error('You can only increase the number of bins')
                if $total <= $current;
        }
    }

    $self->next::method();
}

1;
