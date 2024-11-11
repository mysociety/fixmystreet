package FixMyStreet::SendReport::Open311;

use Moo;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::SendReport'; }

use Open311;

sub send {
    my $self = shift;
    my ( $row, $h ) = @_;

    # There will be only one from FixMyStreet::Queue::Item::Report
    my ($body) = @{ $self->bodies };

    my $conf = $self->body_config->{ $body->id };

    my %open311_params = (
        jurisdiction            => $conf->jurisdiction,
        endpoint                => $conf->endpoint,
        api_key                 => $conf->api_key,
        always_send_latlong     => 1,
        send_notpinpointed      => 0,
        use_service_as_deviceid => 0,
        extended_description    => 1,
        multi_photos            => 0,
        upload_files            => 0,
        always_upload_photos    => 0,
        fixmystreet_body => $body,
    );

    my $contact = $self->fetch_category($body, $row, $row->get_extra_metadata('open311_category_override')) or return;

    my $cobrand = $body->get_cobrand_handler || $row->get_cobrand_logged;
    $cobrand->call_hook(open311_config => $row, $h, \%open311_params, $contact);

    my $db = FixMyStreet::DB->schema->storage;
    $db->txn_do(sub {
        my $row2 = FixMyStreet::DB->resultset('Problem')->search({ id => $row->id }, { for => \'UPDATE' })->single;
        $cobrand->call_hook(open311_update_missing_data => $row2, $h, $contact);
        $row2->update;
        $row->discard_changes;
    });

    # Try and fill in some ones that we've been asked for, but not asked the user for
    my ($include, $exclude) = $cobrand->call_hook(open311_extra_data => $row, $h, $contact);
    my $extra = $row->get_extra_fields();

    push @$extra, @$include if $include;
    if ($exclude) {
        $exclude = join('|', @$exclude);
        @$extra = grep { $_->{name} !~ /$exclude/i } @$extra;
    }

    my $id_field = $contact->id_field;
    foreach (@{$contact->get_extra_fields}) {
        if ($_->{code} eq $id_field) {
            push @$extra, { name => $id_field, value => $row->id };
        } elsif ($_->{code} eq 'closest_address' && $h->{closest_address}) {
            push @$extra, { name => $_->{code}, value => "$h->{closest_address}" };
        } elsif ($_->{code} =~ /^(easting|northing)$/) {
            # NB If there's ever a cobrand with always_send_latlong=0 and
            # send_notpinpointed=0 then this line will need changing to
            # consider the send_notpinpointed check, as per the
            # '#NOTPINPOINTED#' code in perllib/Open311.pm.
            if ( $row->used_map || $open311_params{always_send_latlong} || (
                !$row->used_map && !$row->postcode && $open311_params{send_notpinpointed}
            ) ) {
                push @$extra, { name => $_->{code}, value => $h->{$_->{code}} };
            }
        }
    }

    $row->set_extra_fields( @$extra ) if @$extra;

    my $open311 = Open311->new( %open311_params );

    my $skip = $cobrand->call_hook(open311_pre_send => $row, $open311);
    $skip = $skip && $skip eq 'SKIP';

    my $resp;
    if (!$skip) {
        $resp = $open311->send_service_request( $row, $h, $contact->email );
    }

    # make sure we don't save any changes from above
    $row->discard_changes;

    if ( $skip || $resp ) {
        $row->unset_extra_metadata('open311_category_override'); # If we were overridden, we don't want to keep that for future
        $row->update({ external_id => $resp });
        $self->success( 1 );
    } else {
        $self->error( "Failed to send over Open311\n" ) unless $self->error;
        $self->error( $self->error . "\n" . $open311->error );
    }

    $cobrand->call_hook(open311_post_send => $row, $h, $self);
}

1;
