package FixMyStreet::Cobrand::Enfield;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use FixMyStreet::Geocode::OSPlaces;

sub council_area_id { 2495 }
sub council_area { 'Enfield'; }
sub council_name { return 'Enfield Council'; }
sub council_url { return 'enfield'; }
sub base_url { return FixMyStreet->config('BASE_URL'); }

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    my $type = 'usrn';
    my $classes = [];
    if ($row->get_extra_field_value('pac')) {
        $type = 'uprn';
        $classes = ['LP01', 'LP03', 'LL', 'CC06'];
    }

    my $result = FixMyStreet::Geocode::OSPlaces->reverse_geocode(
        $self, $row->latitude, $row->longitude, $classes);
    if ($result && (my $value = $result->{LPI}{uc $type})) {
        $row->update_extra_field({ name => $type, description => uc $type, value => $value });
    }
}

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail },
    ];

    return $open311_only;
}

sub open311_post_send {
    my ($self, $row, $h, $sender) = @_;

    # Check Open311 was successful
    return unless $row->external_id;
    return if $row->get_extra_metadata('extra_email_sent');

    my $email = $self->feature('open311_email') || return;

    $row->push_extra_fields({ name => 'fixmystreet_id', description => 'FMS reference', value => $row->id });

    my $sender = FixMyStreet::SendReport::Email->new(
        use_verp => 0,
        use_replyto => 1,
        to => [ [ $email, 'FixMyStreet' ] ],
    );

    $sender->send($row, $h);
    if ($sender->success) {
        $row->set_extra_metadata(extra_email_sent => 1);
    }

    $row->remove_extra_field('fixmystreet_id');
}

1;
