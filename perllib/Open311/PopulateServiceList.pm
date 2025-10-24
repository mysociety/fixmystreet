package Open311::PopulateServiceList;

use Moo;
use File::Basename;
use Open311;

has bodies => ( is => 'ro' );
has found_contacts => ( is => 'rw', default => sub { [] } );
has verbose => ( is => 'ro', default => 0 );
has schema => ( is => 'ro', lazy => 1, default => sub { FixMyStreet::DB->schema->connect } );

has _current_body => ( is => 'rw', trigger => sub {
    my ($self, $body) = @_;
    $self->_current_body_cobrand($body->get_cobrand_handler);
} );
has _current_body_cobrand => ( is => 'rw' );
has _current_open311 => ( is => 'rw' );
has _current_service => ( is => 'rw' );

sub process_bodies {
    my $self = shift;

    while ( my $body = $self->bodies->next ) {
        next unless $body->endpoint;
        next unless lc($body->send_method) eq 'open311';
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
    foreach my $service ( @$services ) {
        $self->_current_service( $service );
        $self->process_service;
    }
    $self->_delete_contacts_not_in_service_list;
}

sub process_service {
    my $self = shift;

    my $service_name = $self->_normalize_service_name;

    unless (defined $self->_current_service->{service_code}) {
        warn "Service $service_name has no service code for body @{[$self->_current_body->id]}\n"
            if $self->verbose >= 1;
        return;
    }

    print $self->_current_service->{service_code} . ': ' . $service_name .  "\n" if $self->verbose >= 2;
    my $contacts = $self->schema->resultset('Contact')->search(
        {
            body_id => $self->_current_body->id,
            -OR => [
                email => $self->_current_service->{service_code},
                category => $service_name,
            ]
        }
    );

    if ( $contacts->count() > 1 ) {
        printf(
            "Multiple contacts for service code %s, category %s - Skipping\n",
            $self->_current_service->{service_code},
            $service_name,
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

sub _action_params {
    my ( $self, $action ) = @_;

    return {
        editor => basename($0),
        whenedited => \'current_timestamp',
        note => "$action automatically by script",
    };
}

sub _handle_existing_contact {
    my ( $self, $contact ) = @_;

    my $service_name = $self->_normalize_service_name;
    my $protected = $contact->get_extra_metadata("open311_protect") || $contact->send_method;

    return if $self->_current_body_cobrand && $self->_current_body_cobrand->call_hook(open311_skip_existing_contact => $contact);

    print $self->_current_body->id . " already has a contact for service code " . $self->_current_service->{service_code} . "\n" if $self->verbose >= 2;

    my @actions;
    if ( $contact->state eq 'deleted' ) {
        $contact->category($service_name) unless $protected;
        $contact->email($self->_current_service->{service_code}) unless $protected;
        $contact->send_method(undef); # Let us assume we want to remove any devolved send method in this case
        $contact->state('confirmed');
        push @actions, "undeleted";
    } elsif ( $service_name ne $contact->category || $self->_current_service->{service_code} ne $contact->email ) {
        $contact->category($service_name) unless $protected;
        $contact->email($self->_current_service->{service_code}) unless $protected;
        push @actions, "updated";
    }

    my $metadata = $self->_current_service->{metadata} || '';
    if ( $contact and lc($metadata) eq 'true' ) {
        push @actions, $self->_add_meta_to_contact( $contact );
    } elsif ( $contact and $contact->extra and lc($metadata) eq 'false' ) {
        # check if there are any protected fields that we should not delete
        my @meta = (
            grep { ($_->{protected} || '') eq 'true' }
            @{ $contact->get_extra_fields }
        );
        $contact->set_extra_fields(@meta);
        push @actions, "removed extra fields" if $contact->is_column_changed('extra');
    }

    push @actions, $self->_set_contact_group($contact) unless $protected;
    push @actions, $self->_set_contact_from_keywords($contact);

    eval {
        my $action = join("; ", grep { $_ } @actions);
        $contact->update($self->_action_params($action)) if $action;
    };
    if ( $@ ) {
        warn "Failed to update contact for service code " . $self->_current_service->{service_code} . " for body @{[$self->_current_body->id]}: $@\n"
            if $self->verbose >= 1;
        return;
    }

    push @{ $self->found_contacts }, $self->_current_service->{service_code};
}

sub _create_contact {
    my $self = shift;

    my $service_name = $self->_normalize_service_name;

    my @actions = ("created");
    my $contact = $self->schema->resultset('Contact')->new({
        email => $self->_current_service->{service_code},
        body_id => $self->_current_body->id,
        category => $service_name,
        state => 'confirmed',
        %{ $self->_action_params("created") },
    });

    my $metadata = $self->_current_service->{metadata} || '';
    if ( $contact and lc($metadata) eq 'true' ) {
        push @actions, $self->_add_meta_to_contact( $contact );
    }

    push @actions, $self->_set_contact_group($contact);
    push @actions, $self->_set_contact_from_keywords($contact);

    eval {
        my $action = join("; ", grep { $_ } @actions);
        $contact->note("$action automatically by script");
        $contact->insert;
    };
    if ( $@ ) {
        warn "Failed to create contact for service code " . $self->_current_service->{service_code} . " for body @{[$self->_current_body->id]}: $@\n"
            if $self->verbose >= 1;
        return;
    }

    push @{ $self->found_contacts }, $self->_current_service->{service_code};
    print "created contact for service code " . $self->_current_service->{service_code} . " for body @{[$self->_current_body->id]}\n" if $self->verbose >= 2;
}

sub _add_meta_to_contact {
    my ( $self, $contact ) = @_;

    print "Fetching meta data for " . $self->_current_service->{service_code} . "\n" if $self->verbose >= 2;
    my $meta_data = $self->_current_open311->get_service_meta_info( $self->_current_service->{service_code} );

    unless (ref $meta_data->{attributes} eq 'ARRAY') {
        warn sprintf( "Empty meta data for %s at %s",
                      $self->_current_service->{service_code},
                      $self->_current_body->endpoint )
        # Some have a habit of returning empty metadata, stop noise from that.
        if $self->verbose and $self->_current_body->name !~ /Bristol City Council|Royal Borough of Greenwich/;
        return;
    }

    # check if there are any protected fields that we should not overwrite
    my $protected = {
        map { $_->{code} => $_ }
        grep { ($_->{protected} || '') eq 'true' }
        @{ $contact->get_extra_fields }
    };
    my @meta =
        map { $protected->{$_->{code}} ? delete $protected->{$_->{code}} : $_ }
        @{ $meta_data->{attributes} };

    # and then add back in any protected fields that we don't fetch
    # sort by code for consistent sort order later on
    push @meta, sort { $a->{code} cmp $b->{code} } values %$protected;

    # turn the data into something a bit more friendly to use
    @meta =
        # remove trailing colon as we add this when we display so we don't want 2
        map {
            if ($_->{description}) {
                $_->{description} =~ s/:\s*$//;
                $_->{description} = FixMyStreet::Template::sanitize($_->{description});
            }
            if (defined $_->{order}) {
                $_->{order} += 0;
            }
            $_
        }
        # there is a display order and we only want to sort once
        sort { ($a->{order} || 0) <=> ($b->{order} || 0) }
        @meta;

    # Some Open311 endpoints, such as Bromley and Warwickshire send <metadata>
    # for attributes which we *don't* want to display to the user (e.g. as
    # fields in "category_extras"), or need additional attributes adding not
    # returned by the server for whatever reason.
    $self->_current_body_cobrand && $self->_current_body_cobrand->call_hook(
        open311_contact_meta_override => $self->_current_service, $contact, \@meta);

    $contact->set_extra_fields(@meta);
    return "updated extra fields" if $contact->is_column_changed('extra');
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

sub _set_contact_group {
    my ($self, $contact) = @_;

    my $old_group = $contact->groups;
    my $new_group = $self->_get_new_groups;

    if ($self->_groups_different($old_group, $new_group)) {
        if (@$new_group) {
            $contact->set_extra_metadata(group => @$new_group == 1 ? $new_group->[0] : $new_group);
            return 'group updated';
        } else {
            $contact->unset_extra_metadata('group');
            return 'group removed';
        }
    }
}

sub _set_contact_from_keywords {
    my ($self, $contact) = @_;

    my %keywords = map { $_ => 1 } split /,/, ( $self->_current_service->{keywords} || '' );
    my @actions;

    # These are only one way, we don't e.g. unhide if private keyword goes
    # missing, or mark confirmed if stops being marked inactive/staff - can be
    # fixed manually
    if (!$contact->non_public && $keywords{private}) {
        $contact->non_public(1);
        push @actions, 'marked private';
    }

    if ($contact->state ne 'inactive' && $keywords{inactive}) {
        $contact->state('inactive');
        push @actions, 'marked inactive';
    }

    if ($contact->state ne 'staff' && $keywords{staff}) {
        $contact->state('staff');
        push @actions, 'marked staff';
    }

    my $waste_only = $keywords{waste_only} ? 1 : 0;
    my $type = $contact->get_extra_metadata('type', '') eq 'waste';
    if ($waste_only != $type) { # If the same, nothing to do
        if ($waste_only) { # Newly waste
            $contact->set_extra_metadata(type => 'waste');
            push @actions, "set type to 'waste'";
        } else { # No longer waste
            $contact->unset_extra_metadata('type');
            push @actions, "removed 'waste' type";
        }
    }

    return @actions;
}

sub _get_new_groups {
    my $self = shift;
    return [] unless $self->_current_body_cobrand && $self->_current_body_cobrand->enable_category_groups;

    my $groups = $self->_current_service->{groups} || [];
    my @groups = map { Utils::trim_text($_ || '') } @$groups;
    return \@groups if @groups;

    my $group = $self->_current_service->{group} || [];
    $group = [] if @$group == 1 && !$group->[0]; # <group></group> becomes [undef]...
    @groups = map { Utils::trim_text($_ || '') } @$group;
    return \@groups;
}

sub _groups_different {
    my ($self, $old, $new) = @_;

    return join( ',', sort(@$old) ) ne join( ',', sort(@$new) );
}

sub _delete_contacts_not_in_service_list {
    my $self = shift;

    my $found_contacts = $self->schema->resultset('Contact')->not_deleted->search(
        {
            email => { -not_in => $self->found_contacts },
            body_id => $self->_current_body->id,
        }
    );

    if ($self->_current_body->can_be_devolved) {
        # If the body has can_be_devolved switched on, ignore any
        # contact with its own send method
        $found_contacts = $found_contacts->search(
            { send_method => [ "", undef ] },
        );
    }

    $found_contacts = $self->_delete_contacts_not_in_service_list_cobrand_overrides($found_contacts);

    $found_contacts->update(
        {
            state => 'deleted',
            %{ $self->_action_params("marked as deleted") },
        }
    );
}

sub _delete_contacts_not_in_service_list_cobrand_overrides {
    my ( $self, $found_contacts ) = @_;

    if ($self->_current_body_cobrand && $self->_current_body_cobrand->can('open311_filter_contacts_for_deletion')) {
        return $self->_current_body_cobrand->open311_filter_contacts_for_deletion($found_contacts);
    } else {
        return $found_contacts;
    }
}

1;
