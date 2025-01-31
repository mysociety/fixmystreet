=head1 NAME

FixMyStreet::Roles::Cobrand::KingstonSutton - shared code for Kingston and Sutton WasteWorks

=head1 DESCRIPTION

=cut

package FixMyStreet::Roles::Cobrand::KingstonSutton;

use Moo::Role;
use Hash::Util qw(lock_hash);
with 'FixMyStreet::Roles::Cobrand::SLWP';

use FixMyStreet::App::Form::Waste::Garden::Sacks;
use FixMyStreet::App::Form::Waste::Garden::Sacks::Renew;
use FixMyStreet::App::Form::Waste::Report::SLWP;
use FixMyStreet::App::Form::Waste::Request::Kingston;
use FixMyStreet::App::Form::Waste::Request::Sutton;

=head2 Defaults

=over 4

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * The contact form is for abuse reports only

=cut

sub abuse_reports_only { 1 }

=item * Only waste reports are shown on the cobrand

=cut

around problems_restriction => sub {
    my ($orig, $self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    $rs = $orig->($self, $rs);
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    $rs = $rs->search({
        "$table.cobrand_data" => 'waste',
    });
    return $rs;
};

=item * We can send multiple photos through to Echo, directly

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;
    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

sub state_groups_admin {
    [
        [ New => [ 'confirmed' ] ],
        [ Pending => [ 'investigating', 'action scheduled' ] ],
        [ Closed => [ 'fixed - council', 'unable to fix', 'closed', 'duplicate', 'cancelled' ] ],
        [ Hidden => [ 'unconfirmed', 'hidden', 'partial' ] ],
    ]
}

# Cut down list as only Waste
sub available_permissions {
    my $self = shift;

    return {
        _("Problems") => {
            report_edit => _("Edit reports"),
            report_mark_private => _("View/Mark private reports"),
            contribute_as_another_user => _("Create reports/updates on a user's behalf"),
            contribute_as_anonymous_user => _("Create reports/updates as anonymous user"),
            contribute_as_body => _("Create reports/updates as the council"),
        },
        _("Users") => {
            user_edit => _("Edit users' details/search for their reports"),
            user_manage_permissions => _("Edit other users' permissions"),
            user_assign_body => _("Grant access to the admin"),
        },
        _("Bodies") => {
            template_edit => _("Add/edit response templates"),
            emergency_message_edit => _("Add/edit site message"),
        },
        Waste => {
            wasteworks_config => "Can edit WasteWorks configuration",
        },
    };
}

sub waste_auto_confirm_report { 1 }

my %TASK_IDS = (
    garden => 2247,
);
lock_hash(%TASK_IDS);

my %CONTAINERS = (
    refuse_140 => 1,
    refuse_180 => 35,
    refuse_240 => 2,
    refuse_360 => 3,
    recycling_box => 16,
    recycling_240 => 12,
    paper_240 => 19,
    paper_140 => 36,
    food_indoor => 23,
    food_outdoor => 24,
    garden_240 => 26,
    garden_140 => 27,
    garden_sack => 28,
);
lock_hash(%CONTAINERS);

sub garden_due_days { 30 }

sub garden_staff_provide_email { 1 }

sub waste_password_hidden { 1 }

# For renewal/modify
sub waste_allow_current_bins_edit { 1 }

sub waste_containers {
    my $self = shift;
    my %shared = (
            4 => 'Refuse Blue Sack',
            5 => 'Refuse Black Sack',
            6 => 'Refuse Red Stripe Bag',
            18 => 'Mixed Recycling Blue Striped Bag',
            29 => 'Recycling Single Use Bag',
            21 => 'Paper & Card Reusable Bag',
            22 => 'Paper Sacks',
            30 => 'Paper & Card Recycling Clear Bag',
            7 => 'Communal Refuse bin (240L)',
            8 => 'Communal Refuse bin (360L)',
            9 => 'Communal Refuse bin (660L)',
            10 => 'Communal Refuse bin (1100L)',
            11 => 'Communal Refuse Chamberlain',
            33 => 'Communal Refuse bin (140L)',
            34 => 'Communal Refuse bin (1280L)',
            14 => 'Communal Recycling bin (660L)',
            15 => 'Communal Recycling bin (1100L)',
            25 => 'Communal Food bin (240L)',
            $CONTAINERS{recycling_240} => 'Recycling bin (240L)',
            13 => 'Recycling bin (360L)',
            20 => 'Paper recycling bin (360L)',
            31 => 'Paper 55L Box',
    );
    if ($self->moniker eq 'sutton') {
        return {
            %shared,
            $CONTAINERS{refuse_140} => 'Standard Brown General Waste Wheelie Bin (140L)',
            $CONTAINERS{refuse_240} => 'Larger Brown General Waste Wheelie Bin (240L)',
            $CONTAINERS{refuse_360} => 'Extra Large Brown General Waste Wheelie Bin (360L)',
            $CONTAINERS{refuse_180} => 'Rubbish bin (180L)',
            $CONTAINERS{recycling_box} => 'Mixed Recycling Green Box (55L)',
            $CONTAINERS{paper_240} => 'Paper and Cardboard Green Wheelie Bin (240L)',
            $CONTAINERS{paper_140} => 'Paper and Cardboard Green Wheelie Bin (140L)',
            $CONTAINERS{food_indoor} => 'Small Kitchen Food Waste Caddy (7L)',
            $CONTAINERS{food_outdoor} => 'Large Outdoor Food Waste Caddy (23L)',
            $CONTAINERS{garden_240} => 'Garden Waste Wheelie Bin (240L)',
            $CONTAINERS{garden_140} => 'Garden Waste Wheelie Bin (140L)',
            $CONTAINERS{garden_sack} => 'Garden waste sacks',
        };
    } elsif ($self->moniker eq 'kingston') {
        my $black_bins = $self->{c}->get_param('exchange') ? {
            $CONTAINERS{refuse_140} => 'Black rubbish bin (140L)',
            $CONTAINERS{refuse_240} => 'Black rubbish bin (240L)',
            $CONTAINERS{refuse_360} => 'Black rubbish bin (360L)',
            $CONTAINERS{refuse_180} => 'Black rubbish bin (180L)',
        } : {
            $CONTAINERS{refuse_140} => 'Black rubbish bin',
            $CONTAINERS{refuse_240} => 'Black rubbish bin',
            $CONTAINERS{refuse_360} => 'Black rubbish bin',
            $CONTAINERS{refuse_180} => 'Black rubbish bin',
        };
        return {
            %shared,
            %$black_bins,
            $CONTAINERS{recycling_240} => 'Green recycling bin (240L)',
            13 => 'Green recycling bin (360L)',
            $CONTAINERS{recycling_box} => 'Green recycling box (55L)',
            $CONTAINERS{paper_240} => 'Blue lid paper and cardboard bin (240L)',
            20 => 'Blue lid paper and cardboard bin (360L)',
            $CONTAINERS{food_indoor} => 'Food waste bin (kitchen)',
            $CONTAINERS{food_outdoor} => 'Food waste bin (outdoor)',
            $CONTAINERS{paper_140} => 'Blue lid paper and cardboard bin (180L)',
            $CONTAINERS{garden_240} => 'Garden waste bin (240L)',
            $CONTAINERS{garden_140} => 'Garden waste bin (140L)',
            $CONTAINERS{garden_sack} => 'Garden waste sacks',
        };
    }
}

sub _waste_containers_no_request { {
    6 => 1, # Red stripe bag
    17 => 1, # Recycling purple sack
    29 => 1, # Recycling Single Use Bag
    21 => 1, # Paper & Card Reusable bag
} }

sub waste_quantity_max {
    return (
        $TASK_IDS{garden} => 5, # Garden waste maximum
    );
}

sub waste_munge_bin_services_open_requests {
    my ($self, $open_requests) = @_;
    if ($open_requests->{$CONTAINERS{refuse_140}}) { # Sutton
        $open_requests->{$CONTAINERS{refuse_240}} = $open_requests->{$CONTAINERS{refuse_140}};
    } elsif ($open_requests->{$CONTAINERS{refuse_180}}) { # Kingston
        $open_requests->{$CONTAINERS{refuse_240}} = $open_requests->{$CONTAINERS{refuse_180}};
    } elsif ($open_requests->{$CONTAINERS{refuse_240}}) { # Both
        $open_requests->{$CONTAINERS{refuse_140}} = $open_requests->{$CONTAINERS{refuse_240}};
        $open_requests->{$CONTAINERS{refuse_180}} = $open_requests->{$CONTAINERS{refuse_240}};
        $open_requests->{$CONTAINERS{refuse_360}} = $open_requests->{$CONTAINERS{refuse_240}};
    } elsif ($open_requests->{$CONTAINERS{refuse_360}}) { # Kingston
        $open_requests->{$CONTAINERS{refuse_180}} = $open_requests->{$CONTAINERS{refuse_360}};
        $open_requests->{$CONTAINERS{refuse_240}} = $open_requests->{$CONTAINERS{refuse_360}};
    }
    if ($open_requests->{$CONTAINERS{paper_140}}) {
        $open_requests->{$CONTAINERS{paper_240}} = $open_requests->{$CONTAINERS{paper_140}};
    }
}

=head2 waste_munge_report_form_fields

We use a custom report form to add some text to the "About you" page.

=cut

sub waste_munge_report_form_fields {
    my ($self, $field_list) = @_;
    $self->{c}->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Report::SLWP';
}

=head2 waste_report_form_first_next

After picking a service, we jump straight to the about you page unless it's
bulky, where we ask for more information.

=cut

sub waste_report_form_first_next {
    my $self = shift;
    my $cfg = $self->feature('echo');
    my $bulky_service_id = $cfg->{bulky_service_id};
    return sub {
        my $data = shift;
        return 'notes' if $data->{"service-$bulky_service_id"};
        return 'about_you';
    };
}

=head2 waste_cc_payment_line_item_ref

This is used by the SCP role (all Kingston, Sutton requests) to provide the
reference for the credit card payment. It differs for bulky waste.

=cut

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    if ($p->category eq 'Bulky collection') {
        return $self->_waste_cc_line_item_ref($p, "BULKY", "");
    } elsif ($p->category eq 'Request new container') {
        return $self->_waste_cc_line_item_ref($p, "CCH", "");
    } else {
        return $self->_waste_cc_line_item_ref($p, "GGW", "GW Sub");
    }
}

sub waste_cc_payment_admin_fee_line_item_ref {
    my ($self, $p) = @_;
    return $self->_waste_cc_line_item_ref($p, "GGW", "GW admin charge");
}

sub _waste_cc_line_item_ref {
    my ($self, $p, $type, $str) = @_;
    my $id = $self->waste_payment_ref_council_code . "-$type-" . $p->id;
    my $len = 50 - length($id) - 1;
    if ($str) {
        $str = "-$str";
        $len -= length($str);
    }
    my $name = substr($p->name, 0, $len);
    return "$id-$name$str";
}

sub waste_cc_payment_sale_ref {
    my ($self, $p) = @_;
    return "GGW" . $p->get_extra_field_value('uprn');
}

=head2 bulky_collection_window_start_date

K&S have an 11pm cut-off for looking to book next day collections.

=cut

sub bulky_collection_window_start_date {
    my ($self, $now) = @_;
    my $start_date = $now->clone->truncate( to => 'day' )->add( days => 1 );
    # If past 11pm, push start date one day later
    if ($now->hour >= 23) {
        $start_date->add( days => 1 );
    }
    return $start_date;
}

=head2 Dashboard export

The CSV export includes all reports, including unconfirmed and hidden, and is
adapted in a few ways for Waste reports - including extra columns such as UPRN,
email/phone, payment amount and method.

=cut

# Include unconfirmed and hidden reports in CSV export
sub dashboard_export_include_all_states { 1 }

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->modify_csv_header( Detail => 'Address' );

    $csv->add_csv_columns(
        uprn => 'UPRN',
        user_email => 'User Email',
        user_phone => 'User Phone',
        payment_method => 'Payment method',
        payment_reference => 'Payment reference',
        payment => 'Payment',
        pro_rata => 'Pro rata payment',
        admin_fee => 'Admin fee',
        container => 'Subscription container',
        current_bins => 'Bin count declared',
        quantity => 'Subscription quantity',
    );

    $csv->objects_attrs({
        '+columns' => ['user.email', 'user.phone'],
        join => 'user',
    });

    $csv->csv_extra_data(sub {
        my $report = shift;

        my %fields;
        if ($csv->dbi) {
            %fields = %{$report->{extra}{_field_value} || {}};
        } else {
            my @fields = @{ $report->get_extra_fields() };
            %fields = map { $_->{name} => $_->{value} } @fields;
        }

        my $detail = $csv->dbi ? $report->{detail} : $report->detail;
        $detail =~ s/^.*?\n\n//; # Remove waste category

        return {
            detail => $detail,
            uprn => $fields{uprn},
            $csv->dbi ? (
                user_name_display => $report->{name},
                payment_reference => $fields{PaymentCode} || $report->{extra}{chequeReference} || '',
            ) : (
                user_name_display => $report->name,
                user_email => $report->user->email || '',
                user_phone => $report->user->phone || '',
                payment_reference => $fields{PaymentCode} || $report->get_extra_metadata('chequeReference') || '',
            ),
            payment_method => $fields{payment_method} || '',
            payment => $fields{payment},
            pro_rata => $fields{pro_rata},
            admin_fee => $fields{admin_fee},
            container => $fields{Subscription_Details_Containers},
            current_bins => $fields{current_containers},
            quantity => $fields{Subscription_Details_Quantity},
        };
    });
}

1;
