package FixMyStreet::SendReport::Email::Highways;

use Moo;
extends 'FixMyStreet::SendReport::Email';

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    # Try and make sure we have road details if they're missing
    my $area_name = $row->get_extra_field_value('area_name') || _lookup_site_code($row) || '';

    return unless @{$self->bodies} == 1;
    my $body = $self->bodies->[0];

    my $contact = $self->fetch_category($body, $row) or return;
    my $email = $contact->email;

    # config is read-only, so must step through one-by-one to prevent
    # vivification
    my $area_email = FixMyStreet->config('COBRAND_FEATURES') || {};
    $area_email = $area_email->{open311_email} || {};
    $area_email = $area_email->{highwaysengland} || {};
    $area_email = $area_email->{$area_name};
    $email = $area_email if $area_email;

    @{$self->to} = map { [ $_, $body->name ] } split /,/, $email;
    return 1;
}

sub _lookup_site_code_config { {
    buffer => 15, # metres
    url => "https://tilma.mysociety.org/mapserver/highways",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "Highways",
    accept_feature => sub { 1 }
} }

sub _lookup_site_code {
    my $row = shift;
    my $cfg = _lookup_site_code_config();
    my ($x, $y) = $row->local_coords;
    my $ukc = FixMyStreet::Cobrand::UKCouncils->new;
    my $features = $ukc->_fetch_features($cfg, $x, $y);
    my $nearest = $ukc->_nearest_feature($cfg, $x, $y, $features);
    return unless $nearest;

    my $attr = $nearest->{properties};
    my $db = FixMyStreet::DB->schema->storage;
    $db->txn_do(sub {
        my $row2 = FixMyStreet::DB->resultset('Problem')->search({ id => $row->id }, { for => \'UPDATE' })->single;
        $row2->update_extra_field({ name => 'road_name', value => $attr->{ROA_NUMBER}, description => 'Road name' });
        $row2->update_extra_field({ name => 'area_name', value => $attr->{area_name}, description => 'Area name' });
        $row2->update_extra_field({ name => 'sect_label', value => $attr->{sect_label}, description => 'Road sector' });
        $row2->update;
        $row->discard_changes;
    });

    return $attr->{area_name};
}

1;
