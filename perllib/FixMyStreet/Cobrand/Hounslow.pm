package FixMyStreet::Cobrand::Hounslow;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2483 }
sub council_area { 'Hounslow' }
sub council_name { 'Hounslow Borough Council' }
sub council_url { 'hounslow' }
sub example_places { ( 'TW3 1SN', "Depot Road" ) }

sub map_type { 'Hounslow' }

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    return 'https://fms.hounslowhighways.org';
}

sub enter_postcode_text {
    my ($self) = @_;
    return "Enter a Hounslow street name and area, or postcode";
}

sub admin_user_domain { 'hounslowhighways.org' }

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.468495,-0.366134',
        bounds => [ 51.420739, -0.461502, 51.502850, -0.243443 ],
    };
}

sub on_map_default_status { 'open' }

sub contact_email {
    my $self = shift;
    return join( '@', 'enquiries', $self->council_url . 'highways.org' );
}

sub send_questionnaires { 0 }

sub enable_category_groups { 1 }

sub report_sent_confirmation_email { 'external_id' }

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Check Open311 was successful
    return unless $row->external_id;

    my $e = join( '@', 'enquiries', $self->council_url . 'highways.org' );
    my $sender = FixMyStreet::SendReport::Email->new( to => [ [ $e, 'Hounslow Highways' ] ] );
    $sender->send($row, $h);
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

    # Reports made via FMS.com or the app probably won't have a site code
    # value because we don't display the adopted highways layer on those
    # frontends. Instead we'll look up the closest asset from the WFS
    # service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('site_code')) {
        if (my $site_code = $self->lookup_site_code($row)) {
            push @$extra,
                { name => 'site_code',
                value => $site_code };
        }
    }

    $row->set_extra_fields(@$extra);

    $params->{multi_photos} = 1;
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    # Hounslow want to make it clear in Confirm when an update is left by
    # someone who's not the original reporter.
    unless ($comment->user eq $comment->problem->user) {
        $params->{description} = "[This comment was not left by the original problem reporter] " . $params->{description};
    }
}

sub open311_skip_report_fetch {
  my ($self, $problem) = @_;

  return 1 if $problem->non_public;
}

sub lookup_site_code_config { {
    buffer => 50, # metres
    url => "https://tilma.staging.mysociety.org/mapserver/hounslow",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "streets",
    property => "SITE_CODE",
    accept_feature => sub { 1 }
} }

1;
