package Open311::PopulateServiceList;

use Moose;
use LWP::Simple;
use XML::Simple;
use FixMyStreet::App;
use Open311;

has council_list => ( is => 'ro' );
has found_contacts => ( is => 'rw', default => sub { [] } );

has _current_council => ( is => 'rw' );
has _current_open311 => ( is => 'rw' );
has _current_service => ( is => 'rw' );

my $council_list = FixMyStreet::App->model('DB::Open311conf');

sub process_councils {
    my $self = shift;

    while ( my $council = $self->council_list->next ) {
        next unless $council->endpoint;
        $self->_current_council( $council );
        $self->process_council;
    }
}

sub process_council {
    my $self = shift;

    my $open311 = Open311->new(
        endpoint => $self->_current_council->endpoint,
        jurisdiction => $self->_current_council->jurisdiction,
        api_key => $self->_current_council->api_key
    );

    $self->_current_open311( $open311 );
    $self->_check_endpoints;

    my $list = $open311->get_service_list;
    unless ( $list ) {
        warn "ERROR: no service list found for " . $self->_current_council->area_id . "\n";
        return;
    }
    $self->process_services( $list );
}



sub _check_endpoints {
    my $self = shift;

    # west berks end point not standard
    if ( $self->_current_council->area_id == 2619 ) {
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
    foreach my $service ( @{ $list->{service} } ) {
        $self->_current_service( $service );
        $self->process_service;
    }
    $self->_delete_contacts_not_in_service_list;
}

sub process_service {
    my $self = shift;

    my $category = $self->_current_council->area_id == 2218 ? 
                    $self->_current_service->{description} : 
                    $self->_current_service->{service_name};

    print $self->_current_service->{service_code} . ': ' . $category .  "\n";
    my $contacts = FixMyStreet::App->model( 'DB::Contact')->search(
        {
            area_id => $self->_current_council->area_id,
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

    print $self->_current_council->area_id . " already has a contact for service code " . $self->_current_service->{service_code} . "\n";

    if ( $contact->deleted || $service_name ne $contact->category || $self->_current_service->{service_code} ne $contact->email ) {
        eval {
            $contact->update(
                {
                    category => $service_name,
                    email => $self->_current_service->{service_code},
                    confirmed => 1,
                    deleted => 0,
                    editor => $0,
                    whenedited => \'ms_current_timestamp()',
                    note => 'automatically undeleted by script',
                }
            );
        };

        if ( $@ ) {
            warn "Failed to update contact for service code " . $self->_current_service->{service_code} . " for council @{[$self->_current_council->area_id]}: $@\n";
            return;
        }
    }

    push @{ $self->found_contacts }, $self->_current_service->{service_code};
}

sub _create_contact {
    my $self = shift;

    my $service_name = $self->_normalize_service_name;

    my $contact;
    eval {
        $contact = FixMyStreet::App->model( 'DB::Contact')->create(
            {
                email => $self->_current_service->{service_code},
                area_id => $self->_current_council->area_id,
                category => $service_name,
                confirmed => 1,
                deleted => 0,
                editor => $0,
                whenedited => \'ms_current_timestamp()',
                note => 'created automatically by script',
            }
        );
    };

    if ( $@ ) {
        warn "Failed to create contact for service code " . $self->_current_service->{service_code} . " for council @{[$self->_current_council->area_id]}: $@\n";
        return;
    }

    if ( $contact and lc( $self->_current_service->{metadata} ) eq 'true' ) {
        $self->_add_meta_to_contact( $contact );
    }

    if ( $contact ) {
        push @{ $self->found_contacts }, $self->_current_service->{service_code};
        print "created contact for service code " . $self->_current_service->{service_code} . " for council @{[$self->_current_council->area_id]}\n";
    }
}

sub _add_contact_to_meta {
    my ( $self, $contact ) = @_;

    print "Fetching meta data for $self->_current_service->{service_code}\n";
    my $meta_data = $self->_current_open311->get_service_meta_info( $self->_current_service->{service_code} );

    # turn the data into something a bit more friendly to use
    my @meta =
        # remove trailing colon as we add this when we display so we don't want 2
        map { $_->{description} =~ s/:\s*//; $_ }
        # there is a display order and we only want to sort once
        sort { $a->{order} <=> $b->{order} }
        @{ $meta_data->{attributes}->{attribute} };

    $contact->extra( \@meta );
    $contact->update;
}

sub _normalize_service_name {
    my $self = shift;

    # FIXME - at the moment it makes more sense to use the description
    # for cambridgeshire but need a more flexible way to set this
    my $service_name = $self->_current_council->area_id == 2218 ? 
                        $self->_current_service->{description} : 
                        $self->_current_service->{service_name};
    # remove trailing whitespace as it upsets db queries
    # to look up contact details when creating problem
    $service_name =~ s/\s+$//;

    return $service_name;
}

sub _delete_contacts_not_in_service_list {
    my $self = shift;

    my $found_contacts = FixMyStreet::App->model( 'DB::Contact')->search(
        {
            email => { -not_in => $self->found_contacts },
            area_id => $self->_current_council->area_id,
            deleted => 0,
        }
    );

    $found_contacts->update(
        {
            deleted => 1,
            editor  => $0,
            whenedited => \'ms_current_timestamp()',
            note => 'automatically marked as deleted by script'
        }
    );
}

1;
