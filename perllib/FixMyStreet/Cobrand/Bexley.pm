package FixMyStreet::Cobrand::Bexley;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;
use Time::Piece;

sub council_area_id { 2494 }
sub council_area { 'Bexley' }
sub council_name { 'London Borough of Bexley' }
sub council_url { 'bexley' }
sub get_geocoder { 'Bexley' }
sub map_type { 'MasterMap' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.46088,0.142359',
        bounds => [ 51.408484, 0.074653, 51.515542, 0.2234676 ],
    };
}

sub disable_resend_button { 1 }

# We can resend reports upon category change, unless it will be going to the
# same Symology database, because that will reject saying it already has the
# ID.
sub category_change_force_resend {
    my ($self, $old, $new) = @_;

    # Get the Open311 identifiers
    my $contacts = $self->{c}->stash->{contacts};
    ($old) = map { $_->email } grep { $_->category eq $old } @$contacts;
    ($new) = map { $_->email } grep { $_->category eq $new } @$contacts;

    # Okay if we're switching to/from/within Confirm/Uniform
    return 1 if $old =~ /^(Confirm|Uniform)/ || $new =~ /^(Confirm|Uniform)/;

    # Otherwise, okay if we're switching between Symology DBs, but not within
    return ($old =~ /^StreetLighting/ xor $new =~ /^StreetLighting/);
}

sub on_map_default_status { 'open' }

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    $params->{service_request_id_ext} = $comment->problem->id;

    my $contact = $comment->problem->contact;
    $params->{service_code} = $contact->email;
}

sub open311_get_update_munging {
    my ($self, $comment) = @_;

    # If we've received an update via Open311 that's closed
    # or fixed the report, also close it to updates.
    $comment->problem->set_extra_metadata(closed_updates => 1)
        if !$comment->problem->is_open;
}

sub lookup_site_code_config {
    my ($self, $property) = @_;

    # uncoverable subroutine
    # uncoverable statement
    {
        buffer => 1000, # metres
        url => "https://tilma.mysociety.org/mapserver/bexley",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "Streets",
        property => $property,
        accept_feature => sub { 1 }
    }
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
}

sub open311_extra_data {
    my ($self, $row, $h, $extra, $contact) = @_;

    my $open311_only;
    if ($contact->email =~ /^Confirm/) {
        push @$open311_only,
            { name => 'report_url', description => 'Report URL',
              value => $h->{url} },
            { name => 'title', description => 'Title',
              value => $row->title },
            { name => 'description', description => 'Detail',
              value => $row->detail };

        if (!$row->get_extra_field_value('site_code')) {
            if (my $ref = $self->lookup_site_code($row, 'NSG_REF')) {
                push @$extra, { name => 'site_code', value => $ref, description => 'Site code' };
            }
        }
    } elsif ($contact->email =~ /^Uniform/) {
        # Reports made via the app probably won't have a UPRN because we don't
        # display the road layer. Instead we'll look up the closest asset from the
        # WFS service at the point we're sending the report over Open311.
        if (!$row->get_extra_field_value('uprn')) {
            if (my $ref = $self->lookup_site_code($row, 'UPRN')) {
                push @$extra, { name => 'uprn', description => 'UPRN', value => $ref };
            }
        }
    } else { # Symology
        # Reports made via the app probably won't have a NSGRef because we don't
        # display the road layer. Instead we'll look up the closest asset from the
        # WFS service at the point we're sending the report over Open311.
        if (!$row->get_extra_field_value('NSGRef')) {
            if (my $ref = $self->lookup_site_code($row, 'NSG_REF')) {
                push @$extra, { name => 'NSGRef', description => 'NSG Ref', value => $ref };
            }
        }
    }

    return $open311_only;
}

sub admin_user_domain { 'bexley.gov.uk' }

sub open311_post_send {
    my ($self, $row, $h, $contact) = @_;

    # Check Open311 was successful
    return unless $row->external_id;

    my @lighting = (
        'Lamp post',
        'Light in multi-storey car park',
        'Light in outside car park',
        'Light in park or open space',
        'Traffic bollard',
        'Traffic sign light',
        'Underpass light',
        'Zebra crossing light',
    );
    my %lighting = map { $_ => 1 } @lighting;

    my @flooding = (
        'Flooding in the road',
        'Blocked rainwater gulleys',
    );
    my %flooding = map { $_ => 1 } @flooding;

    my $emails = $self->feature('open311_email') || return;
    my $dangerous = $row->get_extra_field_value('dangerous') || '';

    my $p1_email = 0;
    my $outofhours_email = 0;
    if ($row->category eq 'Abandoned and untaxed vehicles') {
        my $burnt = $row->get_extra_field_value('burnt') || '';
        $p1_email = 1 if $burnt eq 'Yes';
    } elsif ($row->category eq 'Dead animal') {
        $p1_email = 1;
        $outofhours_email = 1;
    } elsif ($row->category eq 'Gulley covers' || $row->category eq 'Manhole covers') {
        my $reportType = $row->get_extra_field_value('reportType') || '';
        if ($reportType eq 'Cover missing' || $dangerous eq 'Yes') {
            $p1_email = 1;
            $outofhours_email = 1;
        }
    } elsif ($row->category eq 'Street cleaning and litter') {
        my $reportType = $row->get_extra_field_value('reportType') || '';
        if ($reportType eq 'Oil spillage' || $dangerous eq 'Yes') {
            $p1_email = 1;
            $outofhours_email = 1;
        }
    } elsif ($row->category eq 'Damage to kerb' || $row->category eq 'Damaged road' || $row->category eq 'Damaged pavement') {
        $p1_email = 1;
        $outofhours_email = 1;
    } elsif (!$lighting{$row->category}) {
        $p1_email = 1 if $dangerous eq 'Yes';
        $outofhours_email = 1 if $dangerous eq 'Yes';
    }

    my @to;
    my $p1_email_to_use = ($contact->email =~ /^Confirm/) ? $emails->{p1confirm} : $emails->{p1};
    push @to, email_list($p1_email_to_use, 'Bexley P1 email') if $p1_email;
    push @to, email_list($emails->{lighting}, 'FixMyStreet Bexley Street Lighting') if $lighting{$row->category};
    push @to, email_list($emails->{flooding}, 'FixMyStreet Bexley Flooding') if $flooding{$row->category};
    push @to, email_list($emails->{outofhours}, 'Bexley out of hours') if $outofhours_email && _is_out_of_hours();
    if ($contact->email =~ /^Uniform/) {
        push @to, email_list($emails->{eh}, 'FixMyStreet Bexley EH');
        $row->push_extra_fields({ name => 'uniform_id', description => 'Uniform ID', value => $row->external_id });
    }

    return unless @to;
    my $sender = FixMyStreet::SendReport::Email->new( to => \@to );

    $self->open311_config($row, $h, {}, $contact); # Populate NSGRef again if needed

    my $extra_data = join "; ", map { "$_->{description}: $_->{value}" } @{$row->get_extra_fields};
    $h->{additional_information} = $extra_data;

    $sender->send($row, $h);
}

sub email_list {
    my ($emails, $name) = @_;
    return unless $emails;
    my @emails = split /,/, $emails;
    my @to = map { [ $_, $name ] } @emails;
    return @to;
}

sub _is_out_of_hours {
    my $time = localtime;
    return 1 if $time->hour > 16 || ($time->hour == 16 && $time->min >= 45);
    return 1 if $time->hour < 8;
    return 1 if $time->wday == 1 || $time->wday == 7;
    return 1 if FixMyStreet::Cobrand::UK::is_public_holiday();
    return 0;
}

1;
