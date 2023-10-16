package FixMyStreet::Cobrand::Bexley;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;
use Time::Piece;
use DateTime;
use Moo;
with 'FixMyStreet::Roles::Open311Multi';

sub council_area_id { 2494 }
sub council_area { 'Bexley' }
sub council_name { 'London Borough of Bexley' }
sub council_url { 'bexley' }
sub get_geocoder { 'Bexley' }
sub default_map_zoom { 4 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.46088,0.142359',
        bounds => [ 51.408484, 0.074653, 51.515542, 0.2234676 ],
    };
}

sub geocode_postcode {
    my ( $self, $s ) = @_;

    # split postcode with a centroid in neighbouring Dartford
    if ($s =~ /^DA5\s*2BD$/i) {
        return {
            latitude => 51.431244,
            longitude => 0.166464,
        };
    }

    return $self->next::method($s);
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

sub munge_report_new_category_list {
    my ($self, $options, $contacts, $extras) = @_;

    my $c = $self->{c};

    if ( $c->user && $c->user->from_body && $c->user->from_body->id == $self->body->id && $self->feature('staff_url') ) {
        for my $category ( keys %{ $self->feature('staff_url') } ) {
            my $urls = $self->feature('staff_url')->{$category};
            for my $extra ( @{ $extras->{$category} } ) {
                if ($extra->{code} eq $urls->[0]) {
                    $extra->{description} =~ s#$urls->[1]#$urls->[2]#s;
                }
            }
        }
    }
}

sub on_map_default_status { 'open' }

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    if ($comment->problem->get_extra_field_value('NSGRef')) {
        $params->{nsg_ref} = $comment->problem->get_extra_field_value('NSGRef');
    }

    $params->{service_request_id_ext} = $comment->problem->id;
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
        accept_feature => sub { 1 }
    }
}

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    $params->{multi_photos} = 1;
}

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

    my $open311_only;
    my $feature = $self->lookup_site_code($row);
    my $extra = $row->get_extra_fields;
    if ($contact->email =~ /^Confirm/) {
        push @$open311_only,
            { name => 'report_url', description => 'Report URL',
              value => $h->{url} },
            { name => 'title', description => 'Title',
              value => $row->title },
            { name => 'description', description => 'Detail',
              value => $row->detail };

        if (!$row->get_extra_field_value('site_code')) {
            if (my $ref = $feature->{properties}{NSG_REF}) {
                $row->update_extra_field({ name => 'site_code', value => $ref, description => 'Site code' });
            }
        }
    } elsif ($contact->email =~ /^Uniform/) {
        # Reports made via the app probably won't have a UPRN because we don't
        # display the road layer. Instead we'll look up the closest asset from the
        # WFS service at the point we're sending the report over Open311.
        if (!$row->get_extra_field_value('uprn')) {
            if (my $ref = $feature->{properties}{UPRN}) {
                $row->update_extra_field({ name => 'uprn', description => 'UPRN', value => $ref });
            }
        }
    } else { # Symology
        # Reports made via the app probably won't have a NSGRef because we don't
        # display the road layer. Instead we'll look up the closest asset from the
        # WFS service at the point we're sending the report over Open311.
        if (!$row->get_extra_field_value('NSGRef')) {
            if (my $ref = $feature->{properties}{NSG_REF}) {
                $row->update_extra_field({ name => 'NSGRef', description => 'NSG Ref', value => $ref });
            }
        }
    }

    if ($feature && $feature->{properties}{ADDRESS}) {
        # Note subtle issue here - the first call to update_extra_field above
        # updates the original extra (stored by SendReport/Open311 in
        # original_extra and thus kept when it 'rolls back' after adding the
        # open311-only entries), but it is changed at the end of that call, so
        # a second call to update_extra_field will update extra but not the
        # original_extra and thus will be lost and not available to
        # open311_post_send. We'll use extra_metadata here anyway.
        my $address = $feature->{properties}{ADDRESS};
        $address =~ s/([\w']+)/\u\L$1/g;
        my $town = $feature->{properties}{TOWN};
        $town =~ s/([\w']+)/\u\L$1/g;
        $row->set_extra_metadata(nsg => { name => $address, area => $town });
    }

    # Add private comments field
    push @$open311_only,
        { name => 'private_comments', description => 'Private comments',
          value => $row->get_extra_metadata('private_comments') || '' };

    return $open311_only;
}

sub admin_user_domain { 'bexley.gov.uk' }

sub open311_post_send {
    my ($self, $row, $h, $sender) = @_;

    # Check Open311 was successful, or if this was the first time a Symology report failed
    if ($sender->contact->email !~ /^(Confirm|Uniform)/) { # it's a Symology report
        # failed at least once, assume email was sent on first failure
        return if $row->send_fail_count;
    } else {
        return unless $row->external_id;
    }

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

    my $is_out_of_hours = _is_out_of_hours();

    my $p1_email = 0;
    my $outofhours_email = 0;
    if ($row->category eq 'Abandoned and untaxed vehicles') {
        my $burnt = $row->get_extra_field_value('burnt') || '';
        $p1_email = 1 if $burnt eq 'Yes';
    } elsif ($row->category eq 'Dead animal') {
        my $reportType = $row->get_extra_field_value('reportType') || '';
        if ($reportType eq 'Horse / Large Animal' || $reportType eq 'Cat / Dog') {
            $outofhours_email = 1;
        };
        $p1_email = 1;
    } elsif ($row->category eq 'Gulley covers' || $row->category eq 'Manhole covers') {
        my $reportType = $row->get_extra_field_value('reportType') || '';
        if ($reportType eq 'Cover missing' || $dangerous eq 'Yes') {
            $p1_email = 1;
            $outofhours_email = 1;
        }
    } elsif ($row->category eq 'Graffiti') {
        my $offensive = $row->get_extra_field_value('offensive') || '';
        $p1_email = 1 if $offensive eq 'Yes';
    } elsif ($row->category eq 'Street cleaning and litter') {
        my $reportType = $row->get_extra_field_value('reportType') || '';
        if ($reportType eq 'Oil Spillage' || $reportType eq 'Clinical / Needles' || $reportType eq 'Glass') {
            $outofhours_email = 1;
            $p1_email = 1;
        }
    } elsif ($row->category eq 'Damage to kerb' || $row->category eq 'Damaged road' || $row->category eq 'Damaged pavement') {
        $p1_email = 1;
        $outofhours_email = 1;
    } elsif ($row->category eq 'Carriageway' || $row->category eq 'Pavement' || $row->category eq 'Grass Verges') { #FlytippingCarriageway, FlytippingGrassVerges, FlytippingPavement
        my $blocking = $row->get_extra_field_value('blocking') || '';
        my $hazardous = $row->get_extra_field_value('hazardous') || '';
        if ($blocking eq 'Yes' || $hazardous eq 'Yes') {
            $outofhours_email = 1;
        }
        if (!$is_out_of_hours || ($blocking eq 'Yes' && $hazardous eq 'Yes')) {
            $p1_email = 1;
        }
    } elsif ($row->category eq 'Alleyway') { #FlytippingAlleyway
        $p1_email = 1 if $dangerous eq 'Yes';
    } elsif ($row->category eq 'Obstructions on pavements and roads') {
        my $reportType = $row->get_extra_field_value('reportType') || '';
        my $issueDescription = $row->get_extra_field_value('issueDescription') || '';
        if ($reportType eq 'Building Materials' && $issueDescription eq 'The issue is causing access problems') {
            $outofhours_email = 1;
        } elsif ($reportType eq 'Cones on Highways') {
            $outofhours_email = 1;
        } elsif ($reportType eq 'Scaffolding' && $dangerous eq 'Yes') {
            $outofhours_email = 1;
        } elsif ($reportType eq 'Skips' && ($issueDescription eq 'Skip is not illuminated' || $issueDescription eq 'Skip in a dangerous position')) {
            $outofhours_email = 1;
        }
        $p1_email = 1;
    } elsif (!$lighting{$row->category}) {
        $p1_email = 1 if $dangerous eq 'Yes';
        $outofhours_email = 1 if $dangerous eq 'Yes';
    }

    my @to;
    my $contact = $sender->contact;
    my $p1_email_to_use = ($contact->email =~ /^Confirm/) ? $emails->{p1confirm} : $emails->{p1};
    push @to, email_list($p1_email_to_use, 'Bexley P1 email') if $p1_email;
    push @to, email_list($emails->{lighting}, 'FixMyStreet Bexley Street Lighting') if $lighting{$row->category};
    push @to, email_list($emails->{flooding}, 'FixMyStreet Bexley Flooding') if $flooding{$row->category};
    push @to, email_list($emails->{outofhours}, 'Bexley out of hours') if $outofhours_email && $is_out_of_hours;
    if ($contact->email =~ /^Uniform/) {
        push @to, email_list($emails->{eh}, 'FixMyStreet Bexley EH');
        $row->push_extra_fields({ name => 'uniform_id', description => 'Uniform ID', value => $row->external_id });
    }

    if (my $nsg = $row->get_extra_metadata('nsg')) {
        $row->push_extra_fields({ name => 'NSGName', description => 'Street name', value => $nsg->{name} });
        $row->push_extra_fields({ name => 'NSGArea', description => 'Street area', value => $nsg->{area} });
        $row->unset_extra_metadata('nsg');
    }
    $row->push_extra_fields({ name => 'fixmystreet_id', description => 'FMS reference', value => $row->id });

    return unless @to;
    my $emailsender = FixMyStreet::SendReport::Email->new(
        use_verp => 0,
        use_replyto => 1,
        to => \@to,
    );

    $self->open311_config($row, $h, {}, $contact); # Populate NSGRef again if needed

    $emailsender->send($row, $h);

    $row->remove_extra_field('NSGName');
    $row->remove_extra_field('NSGArea');
    $row->remove_extra_field('fixmystreet_id');
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
    return 1 if DateTime->now->ymd eq '2022-12-28';
    return 0;
}

sub update_anonymous_message {
    my ($self, $update) = @_;
    my $t = Utils::prettify_dt( $update->confirmed );

    my $staff = $update->user->from_body || $update->get_extra_metadata('is_body_user') || $update->get_extra_metadata('is_superuser');
    return sprintf('Posted anonymously by a non-staff user at %s', $t) if !$staff;
}

sub report_form_extras {
    ( { name => 'private_comments' } )
}

sub report_sent_confirmation_email { 'id' }

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        user_email => 'User Email',
    );

    $csv->objects_attrs({
        '+columns' => ['user.email'],
        join => 'user',
    });

    $csv->csv_extra_data(sub {
        my $report = shift;

        return {
            user_email => $report->user->email || '',
        };
    });
}


1;
