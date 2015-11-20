package Open311::PopulateServiceList;

use Moo;
use Open311;

has bodies => ( is => 'ro' );
has found_contacts => ( is => 'rw', default => sub { [] } );
has verbose => ( is => 'ro', default => 0 );
has schema => ( is => 'ro', lazy => 1, default => sub { FixMyStreet::DB->connect } );

has _current_body => ( is => 'rw' );
has _current_open311 => ( is => 'rw' );
has _current_service => ( is => 'rw' );

sub process_bodies {
    my $self = shift;

    while ( my $body = $self->bodies->next ) {
        next unless $body->endpoint;
        next unless lc($body->send_method) eq 'open311';
        next if $body->jurisdiction =~ /^fixmybarangay_\w+$/; # FMB depts. not using service discovery yet
        $self->_current_body( $body );
        $self->process_body;
    }
}

sub process_body {
    my $self = shift;
    my $open311 = Open311->new(
        endpoint => $self->_current_body->endpoint,
        jurisdiction => $self->_current_body->jurisdiction,
        api_key => $self->_current_body->api_key
    );

    $self->_current_open311( $open311 );
    $self->_check_endpoints;

    my $list = $open311->get_service_list;
    unless ( $list && $list->{service} ) {
        if ($self->verbose >= 1) {
            my $id = $self->_current_body->id;
            my $mapit_url = FixMyStreet->config('MAPIT_URL');
            my $areas = join( ",", keys %{$self->_current_body->areas} );
            warn "Body $id for areas $areas - $mapit_url/areas/$areas.html - did not return a service list\n";
            warn $open311->error;
        }
        return;
    }
    $self->process_services( $list );
}



sub _check_endpoints {
    my $self = shift;

    # west berks end point not standard
    if ( $self->_current_body->areas->{2619} ) {
        $self->_current_open311->endpoints(
            {
                services => 'Services',
                requests => 'Requests'
            }
        );
    }
}


sub process_services {
    my $self = shift;
    my $list = shift;

    $self->found_contacts( [] );
    my $services = $list->{service};
    # XML might only have one result and then squashed the 'array'-ness
    $services = [ $services ] unless ref $services eq 'ARRAY';
    foreach my $service ( @$services ) {
        $self->_current_service( $service );
        $self->process_service;
    }
    $self->_delete_contacts_not_in_service_list;
}

sub process_service {
    my $self = shift;

    my $category = $self->_current_body->areas->{2218} ?
                    $self->_current_service->{description} :
                    $self->_current_service->{service_name};

    print $self->_current_service->{service_code} . ': ' . $category .  "\n" if $self->verbose >= 2;
    my $contacts = $self->schema->resultset('Contact')->search(
        {
            body_id => $self->_current_body->id,
            -OR => [
                email => $self->_current_service->{service_code},
                category => $category,
            ]
        }
    );

    if ( $contacts->count() > 1 ) {
        printf(
            "Multiple contacts for service code %s, category %s - Skipping\n",
            $self->_current_service->{service_code},
            $category,
        );

        # best to not mark them as deleted as we don't know what we're doing
        while ( my $contact = $contacts->next ) {
            push @{ $self->found_contacts }, $contact->email;
        }

        return;
    }

    my $contact = $contacts->first;

    if ( $contact ) {
        $self->_handle_existing_contact( $contact );
    } else {
        $self->_create_contact;
    }
}

sub _handle_existing_contact {
    my ( $self, $contact ) = @_;

    my $service_name = $self->_normalize_service_name;

    print $self->_current_body->id . " already has a contact for service code " . $self->_current_service->{service_code} . "\n" if $self->verbose >= 2;

    if ( $contact->deleted || $service_name ne $contact->category || $self->_current_service->{service_code} ne $contact->email ) {
        eval {
            $contact->update(
                {
                    category => $service_name,
                    email => $self->_current_service->{service_code},
                    confirmed => 1,
                    deleted => 0,
                    editor => $0,
                    whenedited => \'current_timestamp',
                    note => 'automatically undeleted by script',
                }
            );
        };

        if ( $@ ) {
            warn "Failed to update contact for service code " . $self->_current_service->{service_code} . " for body @{[$self->_current_body->id]}: $@\n"
                if $self->verbose >= 1;
            return;
        }
    }

    my $metadata = $self->_current_service->{metadata} || '';
    if ( $contact and lc($metadata) eq 'true' ) {
        $self->_add_meta_to_contact( $contact );
    } elsif ( $contact and $contact->extra and lc($metadata) eq 'false' ) {
        $contact->update( { extra => undef } );
    }

    push @{ $self->found_contacts }, $self->_current_service->{service_code};
}

sub _create_contact {
    my $self = shift;

    my $service_name = $self->_normalize_service_name;

    my $contact;
    eval {
        $contact = $self->schema->resultset('Contact')->create(
            {
                email => $self->_current_service->{service_code},
                body_id => $self->_current_body->id,
                category => $service_name,
                confirmed => 1,
                deleted => 0,
                editor => $0,
                whenedited => \'current_timestamp',
                note => 'created automatically by script',
            }
        );
    };

    if ( $@ ) {
        warn "Failed to create contact for service code " . $self->_current_service->{service_code} . " for body @{[$self->_current_body->id]}: $@\n"
            if $self->verbose >= 1;
        return;
    }

    my $metadata = $self->_current_service->{metadata} || '';
    if ( $contact and lc($metadata) eq 'true' ) {
        $self->_add_meta_to_contact( $contact );
    }

    if ( $contact ) {
        push @{ $self->found_contacts }, $self->_current_service->{service_code};
        print "created contact for service code " . $self->_current_service->{service_code} . " for body @{[$self->_current_body->id]}\n" if $self->verbose >= 2;
    }
}

sub _add_meta_to_contact {
    my ( $self, $contact ) = @_;

    print "Fetching meta data for " . $self->_current_service->{service_code} . "\n" if $self->verbose >= 2;
    my $meta_data = $self->_current_open311->get_service_meta_info( $self->_current_service->{service_code} );

    if ( ref $meta_data->{ attributes }->{ attribute } eq 'HASH' ) {
        $meta_data->{ attributes }->{ attribute } = [
            $meta_data->{ attributes }->{ attribute }
        ];
    }

    if ( ! $meta_data->{attributes}->{attribute} ) {
        warn sprintf( "Empty meta data for %s at %s",
                      $self->_current_service->{service_code},
                      $self->_current_body->endpoint )
        if $self->verbose;
        return;
    }

    # turn the data into something a bit more friendly to use
    my @meta =
        # remove trailing colon as we add this when we display so we don't want 2
        map { $_->{description} =~ s/:\s*//; $_ }
        # there is a display order and we only want to sort once
        sort { $a->{order} <=> $b->{order} }
        @{ $meta_data->{attributes}->{attribute} };

    # Some Open311 endpoints, such as Bromley and Warwickshire send <metadata>
    # for attributes which we *don't* want to display to the user (e.g. as
    # fields in "category_extras"

    my %override = (
        #2482
        'Bromley Council' => [qw(
            service_request_id_ext
            requested_datetime
            report_url
            title
            last_name
            email
            easting
            northing
            report_title
            public_anonymity_required
            email_alerts_requested
        ) ],
        #2243, 
        'Warwickshire County Council' => [qw(
            external_id
            easting
            northing
            closest_address
        ) ],
    );

    if (my $override = $override{ $self->_current_body->name }) {
        my %ignore = map { $_ => 1 } @{ $override };
        @meta = grep { ! $ignore{ $_->{ code } } } @meta;
    }

    $contact->set_extra_fields(@meta);
    $contact->update;
}

sub _normalize_service_name {
    my $self = shift;

    # FIXME - at the moment it makes more sense to use the description
    # for cambridgeshire but need a more flexible way to set this
    my $service_name = $self->_current_body->areas->{2218} ?
                        $self->_current_service->{description} :
                        $self->_current_service->{service_name};
    # remove trailing whitespace as it upsets db queries
    # to look up contact details when creating problem
    $service_name =~ s/\s+$//;

    return $service_name;
}

sub _delete_contacts_not_in_service_list {
    my $self = shift;

    my $found_contacts = $self->schema->resultset('Contact')->search(
        {
            email => { -not_in => $self->found_contacts },
            body_id => $self->_current_body->id,
            deleted => 0,
        }
    );

    # for Warwickshire, which is mixed Open311 and email, don't delete the email
    # addresses
    if ($self->_current_body->name eq 'Warwickshire County Council') {
        $found_contacts = $found_contacts->search(
            {
                email => { -not_like => '%@%' }
            }
        );
    }

    $found_contacts->update(
        {
            deleted => 1,
            editor  => $0,
            whenedited => \'current_timestamp',
            note => 'automatically marked as deleted by script'
        }
    );
}

1;
