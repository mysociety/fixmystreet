package FixMyStreet::Cobrand::Enfield;
use parent 'FixMyStreet::Cobrand::UKCouncils';

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

    if ($row->get_extra_field_value('pac')) {
        if (my $result = $self->_lookup_os('uprn', $row)) {
            if (my $uprn = $result->{LPI}{UPRN}) {
                $row->update_extra_field({ name => 'uprn', description => 'UPRN', value => $uprn });
            }
        }
    } else {
        if (my $result = $self->_lookup_os('usrn', $row)) {
            if (my $usrn = $result->{LPI}{USRN}) {
                $row->update_extra_field({ name => 'usrn', description => 'USRN', value => $usrn });
            }
        }
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

my $BASE = 'https://api.os.uk/search/places/v1/nearest?dataset=LPI&srs=WGS84&radius=1000';
my $CODES = 'fq=CLASSIFICATION_CODE:LP01+CLASSIFICATION_CODE:LP03+CLASSIFICATION_CODE:LL+CLASSIFICATION_CODE:CC06';

sub _lookup_os {
    my ($self, $type, $row) = @_;
    if (my $key = $self->feature('os_places_api_key')) {
        my $url = "$BASE&key=$key&point=" . $row->latitude . ',' . $row->longitude;
        if ($type eq 'uprn') {
            $url .= "&$CODES";
        }
        my $j = FixMyStreet::Geocode::cache('osplaces', $url);
        return $j ? $j->{results}[0] : undef;
    }
    return undef;
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
