package FixMyStreet::Cobrand::CheshireEast;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { 21069 }
sub council_area { 'Cheshire East' }
sub council_name { 'Cheshire East Council' }
sub council_url { 'cheshireeast' }

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible' || !$self->owns_problem( $p );
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'yellow' if $p->is_in_progress;
    return 'red';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '53.180415,-2.349354',
        bounds => [ 52.947150, -2.752929, 53.387445, -1.974789 ],
    };
}

sub enter_postcode_text {
    'Enter a postcode, or a road and place name';
}

sub admin_user_domain { 'cheshireeast.gov.uk' }

sub get_geocoder { 'OSM' }

around open311_extra_data_include => sub {
    my ($orig, $self, $row, $h) = @_;
    my $open311_only = $self->$orig($row, $h);

    if ($row->geocode) {
        my $address = $row->geocode->{resourceSets}->[0]->{resources}->[0]->{address};
        push @$open311_only, (
            { name => 'closest_address', value => $address->{formattedAddress} }
        );
    }

    return $open311_only
};

sub geocoder_munge_results {
    my ($self, $result) = @_;
    $result->{display_name} = '' unless $result->{display_name} =~ /Cheshire East/;
    $result->{display_name} =~ s/, UK$//;
    $result->{display_name} =~ s/, Cheshire East, North West England, England//;
}

sub map_type { 'CheshireEast' }

sub default_map_zoom { 3 }

sub on_map_default_status { 'open' }

sub abuse_reports_only { 1 }

sub send_questionnaires { 0 }

sub anonymous_account {
    my $self = shift;
    return {
        email => $self->feature('anonymous_account') . '@' . $self->admin_user_domain,
        name => 'Anonymous user',
    };
}

# TODO These values may not be accurate
sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://tilma.mysociety.org/mapserver/cheshireeast",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "AdoptedRoads",
    property => "site_code",
    accept_feature => sub { 1 }
} }

sub council_rss_alert_options {
    my $self = shift;
    my $all_areas = shift;
    my $c = shift;

    my %councils = map { $_ => 1 } @{$self->area_types};

    my @options;

    my $body = $self->body;

    my ($council, $ward);
    foreach (values %$all_areas) {
        if ($_->{type} eq 'UTA') {
            $council = $_;
            $council->{id} = $body->id; # Want to use body ID, not MapIt area ID
            $council->{short_name} = $self->short_name( $council );
            ( $council->{id_name} = $council->{short_name} ) =~ tr/+/_/;
        } else {
            $ward = $_;
            $ward->{short_name} = $self->short_name( $ward );
            ( $ward->{id_name} = $ward->{short_name} ) =~ tr/+/_/;
        }
    }

    push @options, {
        type      => 'council',
        id        => sprintf( 'council:%s:%s', $council->{id}, $council->{id_name} ),
        text      => 'All reported problems within the council',
        rss_text  => sprintf( 'RSS feed of problems within %s', $council->{name}),
        uri       => $c->uri_for( '/rss/reports/' . $council->{short_name} ),
    };
    push @options, {
        type     => 'ward',
        id       => sprintf( 'ward:%s:%s:%s:%s', $council->{id}, $ward->{id}, $council->{id_name}, $ward->{id_name} ),
        rss_text => sprintf( 'RSS feed of reported problems within %s ward', $ward->{name}),
        text     => sprintf( 'Reported problems within %s ward', $ward->{name}),
        uri      => $c->uri_for( '/rss/reports/' . $council->{short_name} . '/' . $ward->{short_name} ),
    } if $ward;

    return ( \@options, undef );
}

# Make sure fetched report description isn't shown.
sub filter_report_description { "" }


=head2 open311_extra_data_include

For reports made by staff on behalf of another user, append the staff
user's email & name to the report description.

=cut
around open311_extra_data_include => sub {
    my ($orig, $self, $row, $h) = @_;

    $h->{ce_original_detail} = $row->detail;

    my $contributed_suffix;
    if (my $contributed_by = $row->get_extra_metadata("contributed_by")) {
        if (my $staff_user = $self->users->find({ id => $contributed_by })) {
            $contributed_suffix = "\n\n(this report was made by <" . $staff_user->email . "> (" . $staff_user->name .") on behalf of the user)";
        }
    }

    my $open311_only = $self->$orig($row, $h);
    if ($contributed_suffix) {
        foreach (@$open311_only) {
            if ($_->{name} eq 'description') {
                $_->{value} .= $contributed_suffix;
            }
        }
        $row->detail($row->detail . $contributed_suffix);
    }

    return $open311_only;
};

sub open311_post_send {
    my ($self, $row, $h, $contact) = @_;

    $row->detail($h->{ce_original_detail});
}


1;
