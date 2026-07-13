=head1 NAME

FixMyStreet::Cobrand::Dudley - code specific to the Dudley cobrand

=head1 SYNOPSIS

Dudley is a metropolitan district authority, with a Symology backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Dudley;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;
use Moo;
with 'FixMyStreet::Roles::Cobrand::OpenUSRN';

sub council_area_id { 2522 }
sub council_area { 'Dudley'; }
sub council_name { 'Dudley Borough Council' }
sub council_url { 'dudley' }

# Created with bin/fixmystreet.com/generate_council_location
sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    my $town = 'Dudley';
    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        centre => '52.4828778776603,-2.1087441438586',
        span   => '0.132208941295367,0.180437882042669',
        bounds => [ 52.4260142691841, -2.19194291862399, 52.5582232104795, -2.01150503658132 ],
        result_strip => ', West Midlands, England',
    };
}

sub enter_postcode_text { 'Enter a Dudley postcode, street name and area, or report reference number' }

=over 4

=item * dudley.gov.uk users can always be found in the admin

=cut

sub admin_user_domain { 'dudley.gov.uk' }

sub abuse_reports_only { 1 }

=item * Only open reports on map by default

=cut

sub on_map_default_status { 'open' }

=item * The default map view shows closed/fixed reports for 30 days

=cut

sub report_age {
    return {
        closed => '30 days',
        fixed  => '30 days',
    };
}

=item * We do not show reports made before go-live on 2026-09-01.

=cut

sub cut_off_date { '2026-09-01' }

=item * Some customised pins (yellow/blue/green/grey)

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;

    return 'grey-cross' if $p->is_closed;
    return 'green-tick' if $p->is_fixed;
    return 'yellow-cone' if $p->state eq 'confirmed';
    return 'blue-work'; # all the other `open_states` like "in progress"
}

=item * Send a confirmation email once the report has been sent, quoting its FMS ID

=cut

sub report_sent_confirmation_email { 'id' }

=item * No questionnaires

=cut

sub send_questionnaires { 0 }

=item * Starts the map more zoomed in than the default

=cut

sub default_map_zoom { 5 }

=item * Custom label for the title field for new reports.

=cut

sub new_report_title_field_label { "Location of the problem" }

=item * Potholes category only at present

=cut

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');

    $rs = $rs->to_body($self->body);

    my $date = $self->cut_off_date;
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    $rs = $rs->search({
        "$table.created" => { '>=', $date },
        "$table.category" => 'Potholes',
    });
    return $rs;
}

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( {
        'me.category' => 'Potholes',
    } );
    # return $rs->search( { -or => [
    #     'me.send_method' => undef, # Open311 categories, or National Highways
    #     'me.send_method' => '', # Open311 categories that have been edited in the admin
    # ] } );
}

=item * Fetch the nearest USRN if we don't have it already

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    if (!$row->get_extra_field_value('NSGRef')) {
        if (my $ref = $self->lookup_site_code($row)) {
            $row->update_extra_field({ name => 'NSGRef', description => 'NSG Ref', value => $ref });
        }
    }
}

=item * Include the report URL in the Open311 submission

=cut

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
    ];

    my $title = $row->title;
    if ( $h->{closest_address} ) {
        my $addr = $h->{closest_address}->summary;

        $addr =~ s/, England//;
        $addr =~ s/, United Kingdom$//;

        $title .= '; Nearest calculated address = ' . $addr;
    }

    push @$open311_only, { name => 'title', value => $title };
    push @$open311_only, { name => 'description', value => $row->detail };

    return $open311_only;
}

=item * Also send an email on Open311 categories, if email provided

=back

=cut

sub open311_post_send {
    my ($self, $row, $h) = @_;

    return unless $row->external_id;
    return if $row->get_extra_metadata('extra_email_sent');

    my $emails = $self->feature('open311_email') or return;
    my $dest = $emails->{$row->category} or return;
    $dest = [ $dest, 'FixMyStreet' ];

    $row->push_extra_fields({ name => 'fixmystreet_id', description => 'FMS reference', value => $row->id });

    my $sender = FixMyStreet::SendReport::Email->new(
        use_verp => 0, use_replyto => 1, to => [ $dest ] );
    $sender->send($row, $h);
    if ($sender->success) {
        $row->set_extra_metadata(extra_email_sent => 1);
    }

    $row->remove_extra_field('fixmystreet_id');
}

1;
