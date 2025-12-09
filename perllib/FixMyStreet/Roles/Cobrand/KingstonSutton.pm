=head1 NAME

FixMyStreet::Roles::Cobrand::KingstonSutton - shared code for Kingston and Sutton WasteWorks

=head1 DESCRIPTION

=cut

package FixMyStreet::Roles::Cobrand::KingstonSutton;

use Moo::Role;
use Hash::Util qw(lock_hash);
use List::Util qw(max);

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

=back

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;
    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

=head2 state_groups_admin / available_permissions

We do not need all the states and permissions for only WasteWorks.

=cut

sub state_groups_admin {
    [
        [ New => [ 'confirmed' ] ],
        [ Pending => [ 'investigating', 'action scheduled' ] ],
        [ Closed => [ 'fixed - council', 'unable to fix', 'closed', 'duplicate', 'cancelled' ] ],
        [ Hidden => [ 'unconfirmed', 'hidden', 'partial' ] ],
    ]
}

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

=head2 Garden

=over 4

=item * Garden subscriptions can be renewed 30 days before they end.

=cut

sub garden_due_date {
    my ($self, $end_date) = @_;
    return $end_date->subtract(days => 30);
};

=item * Even staff must provide an email address for garden subscriptions

=cut

sub garden_staff_provide_email { 1 }

=item * Do not offer people to set a password

=cut

sub waste_password_hidden { 1 }

=item * Allow people to edit the current number of bins for renewal/modify

=back

=cut

sub waste_allow_current_bins_edit { 1 }

=head2 waste_munge_report_form_fields

We use a custom report form to add some text to the "About you" page.

=cut

sub waste_munge_report_form_fields {
    my ($self, $field_list) = @_;
    $self->{c}->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Report::SLWP';
}

=head2 waste_report_form_first_next

After picking a service, we jump straight to the about you page unless it's
bulky or small items, where we ask for more information.

=cut

sub waste_report_form_first_next {
    my $self = shift;
    my $cfg = $self->feature('echo');
    my $bulky_service_id       = $cfg->{bulky_service_id};
    my $small_items_service_id = $cfg->{small_items_service_id};
    return sub {
        my $data = shift;
        return 'notes'
            if ( $bulky_service_id && $data->{"service-$bulky_service_id"} )
            || ( $small_items_service_id && $data->{"service-$small_items_service_id"} );
        return 'about_you';
    };
}

=head2 waste_munge_enquiry_form_pages

the bin not returned flow has some more complex setup depending on whether
the property has an assisted collection or not, with an extra question,
and showing/hiding different notices.

=cut

sub waste_munge_enquiry_form_pages {
    my ($self, $pages, $fields) = @_;
    my $c = $self->{c};
    my $category = $c->get_param('category');

    # add the service to the main fields form page
    $pages->[1]{intro} = 'enquiry-intro.html';
    $pages->[1]{title} = _enquiry_nice_title($category);

    return unless $category eq 'Bin not returned';;

    my $assisted = $c->stash->{assisted_collection};
    if ($assisted) {
        # add extra first page with extra question
        $c->stash->{first_page} = 'now_returned';
        unshift @$pages, now_returned => {
            fields => [ 'now_returned', 'continue' ],
            intro => 'enquiry-intro.html',
            title => _enquiry_nice_title($category),
            next => 'enquiry',
        };
        push @$fields, now_returned => {
            type => 'Select',
            widget => 'RadioGroup',
            required => 1,
            label => 'has the container now been returned to the property?',
            options => [
                { label => 'Yes', value => 'yes' },
                { label => 'No', value => 'no' },
            ],
        };

        # remove any non-assisted extra notices
        my @new;
        for (my $i=0; $i<@$fields; $i+=2) {
            if ($fields->[$i] !~ /^extra_notassisted/i) {
                push @new, $fields->[$i], $fields->[$i+1];
            }
        }
        @$fields = @new;
        $pages->[3]{fields} = [ grep { !/^extra_notassisted/i } @{$pages->[3]{fields}} ];
        $pages->[3]{update_field_list} = sub {
            my $form = shift;
            my $c = $form->c;
            my $data = $form->saved_data;
            my $returned = $data->{now_returned} || '';
            my $key = lc($returned) eq 'no' ? 'extra_AssistedReturned' : 'extra_AssistedNotReturned';
            return {
                category => { default => $c->get_param('category') },
                service_id => { default => $c->get_param('service_id') },
                $key => { widget => 'Hidden' },
            }
        };
    } else {
        # remove any assisted extra notices
        my @new;
        for (my $i=0; $i<@$fields; $i+=2) {
            if ($fields->[$i] !~ /^extra_assisted/i) {
                push @new, $fields->[$i], $fields->[$i+1];
            }
        }
        @$fields = @new;
        $pages->[1]{fields} = [ grep { !/^extra_assisted/i } @{$pages->[1]{fields}} ];
    }
}

sub _enquiry_nice_title {
    my $category = shift;
    if ($category eq 'Bin not returned') {
        $category = 'Wheelie bin, box or caddy not returned correctly after collection';
    } elsif ($category eq 'Waste spillage') {
        $category = 'Spillage during collection';
    } elsif ($category eq 'Complaint against time') {
        $category = 'Issue with collection';
    } elsif ($category eq 'Failure to Deliver Bags/Containers') {
        $category = 'Issue with delivery';
    }
    return $category;
}

=head2 waste_cc_payment_line_item_ref

This is used by the SCP role (all Kingston, Sutton requests) to provide the
reference for the credit card payment. It differs for bulky waste.

=cut

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    if ($p->category eq 'Bulky collection') {
        my $type = $self->moniker eq 'sutton' ? 'BWB' : 'BULKY';
        return $self->_waste_cc_line_item_ref($p, $type, "");
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

    my $config = $self->wasteworks_config || {};
    my $max_items = max(
        $config->{small_items_per_collection_max} || 0,
        $config->{items_per_collection_max} || 0,
        5
    );

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
        # Escalations
        $self->moniker eq 'sutton' ? (original_ref => 'Original reference') : (),
        map { "item_" . $_ => "Item $_" } (1..$max_items),
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

        my $data = {
            detail => $detail,
            uprn => $fields{uprn},
            $csv->dbi ? (
                user_name_display => $report->{name},
                payment_reference => $report->{extra}{payment_reference} || '',
            ) : (
                user_name_display => $report->name,
                user_email => $report->user->email || '',
                user_phone => $report->user->phone || '',
                payment_reference => $report->get_extra_metadata('payment_reference') || '',
            ),
            payment_method => $fields{payment_method} || '',
            payment => $fields{payment},
            pro_rata => $fields{pro_rata},
            admin_fee => $fields{admin_fee},
            container => $fields{Paid_Container_Type} || $fields{Subscription_Details_Containers},
            current_bins => $fields{current_containers},
            quantity => $fields{Paid_Container_Quantity} || $fields{Subscription_Details_Quantity},
            original_ref => $fields{original_ref},
        };

        my $extra = $csv->_extra_metadata($report);
        %$data = (%$data, map {$_ => $extra->{$_} || ''} grep { $_ =~ /^(item_\d+)$/ } keys %$extra);

        return $data;
    });
}

1;
