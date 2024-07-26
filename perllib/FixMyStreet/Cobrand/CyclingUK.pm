package FixMyStreet::Cobrand::CyclingUK;
use base 'FixMyStreet::Cobrand::FixMyStreet';

use Moo;

=item path_to_web_templates

We want to use the fixmystreet.com templates as a fallback instead of
fixmystreet-uk-councils as this cobrand is effectively a reskin of .com rather
than a cobrand for a single council.

=cut

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web/cyclinguk' ),
        FixMyStreet->path_to( 'templates/web/fixmystreet.com' ),
    ];
}

=item path_to_email_templates

Similarly, we want to ensure our custom email templates are used.

=cut

sub path_to_email_templates {
    my ( $self, $lang_code ) = @_;
    return [
        FixMyStreet->path_to( 'templates', 'email', 'cyclinguk' ),
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com'),
        FixMyStreet->path_to( 'templates', 'email', 'default', $lang_code ),
    ];
}


sub privacy_policy_url { 'https://www.cyclinguk.org/article/fill-hole-privacy-notice' }

=item problems_restriction

This cobrand only shows reports made on it, not those from FMS.com or others.

=cut


sub problems_restriction {
    my ($self, $rs) = @_;

    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    return $rs->search({
        "$table.cobrand" => "cyclinguk"
    });
}

sub problems_sql_restriction {
    my ($self, $item_table) = @_;

    return "AND cobrand = 'cyclinguk'";
}

=item problems_on_map_restriction

Same restriction on map as problems_restriction above.

=cut


sub problems_on_map_restriction {
    my ($self, $rs) = @_;
    $self->problems_restriction($rs);
}

sub updates_restriction {
    my ($self, $rs) = @_;
    return $rs->search({ 'problem.cobrand' => 'cyclinguk' }, { join => 'problem' });
}


=item allow_report_extra_fields

Enables the ReportExtraField feature which allows the addition of
site-wide extra questions when making reports. Used for the custom Cycling UK
questions when making reports.

=cut

sub allow_report_extra_fields { 1 }

sub base_url { FixMyStreet::Cobrand::UKCouncils::base_url($_[0]) }

sub contact_name {
    my $self = shift;
    return $self->feature('contact_name') || $self->next::method();
}

sub contact_email {
    my $self = shift;
    return $self->feature('contact_email') || $self->next::method();
}

sub do_not_reply_email {
    my $self = shift;
    return $self->feature('do_not_reply_email') || $self->next::method();
}


sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    # Make sure only Cycling UK staff can access admin
    return 1 if $user->from_body->name eq 'Cycling UK';
}

=item * Users with a cyclinguk.org email can always be found in the admin.

=cut

sub admin_user_domain { 'cyclinguk.org' }

=item users_restriction

Cycling UK staff can only see users who are also Cycling UK staff, or have a
cyclinguk.org email address, or who have sent a report or update using the
cyclinguk cobrand.

=cut

sub users_restriction { FixMyStreet::Cobrand::UKCouncils::users_restriction($_[0], $_[1]) }


=item dashboard_extra_bodies

Cycling UK dashboard should show all bodies that have received a report made
via the cobrand.

=cut

sub dashboard_extra_bodies {
    my ($self) = @_;

    my @results = FixMyStreet::DB->resultset('Problem')->search({
        cobrand => 'cyclinguk',
    }, {
        distinct => 1,
        columns => { bodies_str => \"regexp_split_to_table(bodies_str, ',')" }
    })->all;

    my @bodies = map { $_->bodies_str } @results;

    return FixMyStreet::DB->resultset('Body')->search(
        { 'id' => { -in => \@bodies } },
        { order_by => 'name' }
    )->active->all;
}

sub dashboard_default_body {};

=item get_body_sender

Reports made on the Cycling UK staging site should never be sent anywhere,
as we don't want to unexpectedly send Pro clients reports made as part of
Cycling UK's testing.

=cut

sub get_body_sender {
    my ( $self, $body, $problem ) = @_;

    return { method => 'Blackhole' } if FixMyStreet->config('STAGING_SITE');

    return $self->SUPER::get_body_sender($body, $problem);
}

sub get_body_handler_for_problem {
    my ( $self, $problem ) = @_;

    # want to force CyclingUK cobrand on staging so our get_body_sender is used
    # and reports aren't sent anywhere.
    return $self if FixMyStreet->config('STAGING_SITE');

    return $self->SUPER::get_body_handler_for_problem($problem);
}

=item dashboard_export_problems_add_columns

Reports made on the Cycling UK site have some extra questions shown to the
user - the answers to all of these are included in the CSV output.

=cut

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        injury_suffered => 'Injury suffered?',
        property_damage => 'Property damage?',
        transport_mode => 'Mode of transport',
        transport_other => 'Mode of transport (other)',
        first_name => 'First name',
        last_name => 'Last name',
        user_email => 'User Email',
        marketing => 'Marketing opt-in?',
    );

    $csv->objects_attrs({
        '+columns' => ['user.email'],
        join => 'user',
    });

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $name = $csv->dbi ? $report->{name} : $report->name;
        my ($first, $last) = $name =~ /^(\S*)(?: (.*))?$/;

        return {
            injury_suffered => $csv->_extra_metadata($report, 'CyclingUK_injury_suffered') || '',
            property_damage => $csv->_extra_metadata($report, 'CyclingUK_property_damage') || '',
            transport_mode => $csv->_extra_metadata($report, 'CyclingUK_transport_mode') || '',
            transport_other => $csv->_extra_metadata($report, 'CyclingUK_transport_other') || '',
            marketing => $csv->_extra_metadata($report, 'CyclingUK_marketing_opt_in') || '',
            first_name => $first || '',
            last_name => $last || '',
            $csv->dbi ? () : (
                user_email => $report->user ? $report->user->email : '',
            )
        };
    });
}

=item disable_phone_number_entry

Cycling UK cobrand does not ask for user's phone number when making their report.

=cut

sub disable_phone_number_entry { 1 }

sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    my $opt_in = $self->{c}->get_param("marketing_opt_in") ? 'yes' : 'no';
    $report->update_extra_field({ name => 'CyclingUK_marketing_opt_in', value => $opt_in });

    my @keys = ('injury_suffered', 'property_damage', 'transport_mode', 'transport_other', 'marketing_opt_in');
    my %keys = map { "CyclingUK_" . $_ => 1 } @keys;
    my @fields;
    foreach (@{$report->get_extra_fields}) {
        if ($keys{$_->{name}}) {
            $report->set_extra_metadata($_->{name} => $_->{value});
        } else {
            push @fields, $_;
        }
    }
    $report->set_extra_fields(@fields);

    return $self->SUPER::report_new_munge_before_insert($report);
}


=item extra_contact_validation

This is used on the FixMyStreet cobrand for an anti-spam question. We don't have
that question on the CyclingUK cobrand so need to override this method otherwise
the validation in FixMyStreet will prevent the form being submitted.

=cut

sub extra_contact_validation {}

1;
