package FixMyStreet::Script::Alerts;

use strict;
use warnings;

use DateTime::Format::Pg;
use IO::String;
use Math::Trig qw(great_circle_distance deg2rad);

use FixMyStreet::Gaze;
use FixMyStreet::MapIt;

use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use FixMyStreet::Email;
use FixMyStreet::Geocode::Address;
use FixMyStreet::Map;
use FixMyStreet::App::Model::PhotoSet;

my $parser = DateTime::Format::Pg->new();

# Child must have confirmed, id, email, state(!) columns
# If parent/child, child table must also have name and text
#   and foreign key to parent must be PARENT_id

sub send_other {
    my $rs = FixMyStreet::DB->resultset('AlertType');
    my $q = $rs->search( { ref => { -not_like => '%local_problems%' } } )->search( { ref => { "!=" => 'new_updates' } } );
    while (my $alert_type = $q->next) {
        send_alert_type($alert_type);
    }
}

sub send_updates {
    my $rs = FixMyStreet::DB->resultset('AlertType');
    my $alert_type = $rs->find( { ref => 'new_updates' } );
    send_alert_type($alert_type);
}

sub send_alert_type {
    my $alert_type = shift;
    my $schema = $alert_type->result_source->schema;

    my $ref = $alert_type->ref;
    my $head_table = $alert_type->head_table;
    my $item_table = $alert_type->item_table;
    my $query = 'select alert.id as alert_id, alert.user_id as alert_user_id, alert.lang as alert_lang, alert.cobrand as alert_cobrand,
        alert.cobrand_data as alert_cobrand_data, alert.parameter as alert_parameter, alert.parameter2 as alert_parameter2, ';
    if ($head_table) {
        $query .= "
               $item_table.id as item_id, $item_table.text as item_text,
               $item_table.name as item_name, $item_table.anonymous as item_anonymous,
               $item_table.confirmed as item_confirmed,
               $item_table.photo as item_photo,
               $item_table.problem_state as item_problem_state,
               $item_table.extra as item_extra,
               $item_table.private_email_text as item_private_email_text,
               $head_table.cobrand as item_cobrand,
               $head_table.*
        from alert, $item_table, $head_table
            where alert.parameter::integer = $head_table.id
            and $item_table.${head_table}_id = $head_table.id
            ";
    } else {
        $query .= " $item_table.*,
               $item_table.cobrand as item_cobrand,
               $item_table.id as item_id
        from alert, $item_table
        where 1 = 1";
    }
    $query .= "
        and alert_type='$ref' and whendisabled is null and $item_table.confirmed >= whensubscribed
        and $item_table.confirmed >= current_timestamp - '7 days'::interval
         and (select whenqueued from alert_sent where alert_sent.alert_id = alert.id and alert_sent.parameter::integer = $item_table.id) is null
        and $item_table.user_id <> alert.user_id
        and " . $alert_type->item_where . "
        and alert.confirmed = 1
        order by alert.id, $item_table.confirmed";
    # XXX Ugh - needs work
    $query =~ s/\?/alert.parameter/ if ($query =~ /\?/);
    $query =~ s/\?/alert.parameter2/ if ($query =~ /\?/);

    $query = FixMyStreet::DB->schema->storage->dbh->prepare($query);
    $query->execute();
    my $last_alert_id;
    my $last_problem_state = 'confirmed';
    my %data = ( template => $alert_type->template, data => [], schema => $schema );
    while (my $row = $query->fetchrow_hashref) {
        $row->{is_new_update} = defined($row->{item_text});

        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($row->{alert_cobrand})->new();
        $cobrand->set_lang_and_domain( $row->{alert_lang}, 1, FixMyStreet->path_to('locale')->stringify );

        # Cobranded and non-cobranded messages can share a database. In this case, the conf file
        # should specify a vhost to send the reports for each cobrand, so that they don't get sent
        # more than once if there are multiple vhosts running off the same database. The email_host
        # call checks if this is the host that sends mail for this cobrand.
        next unless $cobrand->email_host;

        # this is for the new_updates alerts
        next if $row->{non_public} and $row->{user_id} != $row->{alert_user_id};

        next unless FixMyStreet::DB::Result::Problem::visible_states()->{$row->{state}};

        next if alert_check_cobrand($row->{alert_cobrand}, $row->{item_cobrand});

        $schema->resultset('AlertSent')->create( {
            alert_id  => $row->{alert_id},
            parameter => $row->{item_id},
        } );

        if ($last_alert_id && $last_alert_id != $row->{alert_id}) {
            $last_problem_state = 'confirmed';
        }

        # Here because report is needed by e.g. _extra_new_update_data,
        # and the state display function
        my $report;
        if ($ref eq 'new_updates') {
            # Get a report object for its photo and static map
            $report = $schema->resultset('Problem')->find({ id => $row->{id} });
        }

        # this is currently only for new_updates
        if ($row->{is_new_update}) {
            # this might throw up the odd false positive but only in cases where the
            # state has changed and there was already update text
            if ($row->{item_problem_state} && $last_problem_state ne $row->{item_problem_state}) {
                my $update = '';
                unless ( $cobrand->call_hook( skip_alert_state_changed_to => $report ) ) {
                    my $cobrand_name = $report->cobrand_name_for_state($cobrand);
                    my $state = FixMyStreet::DB->resultset("State")->display($row->{item_problem_state}, 1, $cobrand_name);

                    $update = _('State changed to:') . ' ' . $state;
                }

                $row->{item_text_original} = $row->{item_text};
                $row->{item_text} = $row->{item_text} ? $row->{item_text} . "\n\n" . $update :
                                                        $update;
                if ($row->{item_private_email_text} && $report->cobrand_data ne 'waste') {
                    $row->{item_private_email_text} = $row->{item_private_email_text} . "\n\n" . $update;
                }
                $last_problem_state = $row->{item_problem_state};
            }
            next unless $row->{item_text};
        }

        if ($last_alert_id && $last_alert_id != $row->{alert_id}) {
            _send_aggregated_alert(%data);
            %data = ( template => $alert_type->template, data => [], schema => $schema );
        }

        # create problem status message for the templates
        if ( FixMyStreet::DB::Result::Problem::fixed_states()->{$row->{state}} ) {
            $data{state_message} = _("This report is currently marked as fixed.");
        } elsif ( FixMyStreet::DB::Result::Problem::closed_states()->{$row->{state}} ) {
            $data{state_message} = _("This report is currently marked as closed.")
        } else {
            $data{state_message} = _("This report is currently marked as open.");
        }

        if (!$data{alert_user_id}) {
            if ($ref eq 'new_updates') {
                $data{report} = $report;
            }
        }

        # this is currently only for new_updates
        if ($row->{is_new_update}) {
            _extra_new_update_data($row, \%data, $cobrand, $schema);
        # this is ward and council problems
        } else {
            _extra_new_area_data($row, $ref);
        }
        push @{$data{data}}, $row;

        if (!$data{alert_user_id}) {
            %data = (%data, %$row);
            my $user = $schema->resultset('User')->find( {
                id => $row->{alert_user_id}
            } );
            $data{alert_user} = $user;
            if ($ref eq 'area_problems') {
                my $va_info = FixMyStreet::MapIt::call('area', $row->{alert_parameter});
                $data{area_name} = $va_info->{name};
            } elsif ($ref eq 'council_problems' || $ref eq 'ward_problems') {
                my $body = FixMyStreet::DB->resultset('Body')->find({ id => $row->{alert_parameter} });
                $data{area_name} = $body->name;
            }
            if ($ref eq 'ward_problems') {
                my $va_info = FixMyStreet::MapIt::call('area', $row->{alert_parameter2});
                $data{ward_name} = $va_info->{name};
            }
        }
        $data{cobrand} = $cobrand;
        $data{cobrand_data} = $row->{alert_cobrand_data};
        $data{lang} = $row->{alert_lang};
        $last_alert_id = $row->{alert_id};
    }
    if ($last_alert_id) {
        _send_aggregated_alert(%data);
    }
}

sub _extra_new_update_data {
    my ($row, $data, $cobrand, $schema) = @_;

    my $url = $cobrand->base_url_for_report($row);
    if ( $cobrand->moniker ne 'zurich' && $row->{alert_user_id} == $row->{user_id} ) {
        # This is an alert to the same user who made the report - make this a login link
        # Don't bother with Zurich which has no accounts
        my $token_obj = $schema->resultset('Token')->create( {
            scope => 'alert_to_reporter',
            data  => {
                id => $row->{id},
            }
        } );
        $data->{problem_url} = $url . "/R/" . $token_obj->token;

        # Also record timestamp on report if it's an update about being fixed...
        if (FixMyStreet::DB::Result::Problem::fixed_states()->{$row->{state}} || FixMyStreet::DB::Result::Problem::closed_states()->{$row->{state}}) {
            $data->{report}->set_extra_metadata_if_undefined('closure_alert_sent_at', time());
            $data->{report}->update;
        }
    } else {
        $data->{problem_url} = $url . "/report/" . $row->{id};
    }

    my $dt = $parser->parse_timestamp( $row->{item_confirmed} );
    # We need to always set this otherwise we end up with the DateTime
    # object being in the floating timezone in which case applying a
    # subsequent timezone set will have no effect.
    # this is basically recreating the code from the inflate wrapper
    # in the database model.
    FixMyStreet->set_time_zone($dt);
    $row->{confirmed} = $dt;

    # Hack in the image for the non-object updates
    my $photo = $row->{item_photo};
    my $id = $row->{item_id};
    $row->{get_first_image_fp} = sub {
        return FixMyStreet::App::Model::PhotoSet->new({
            object_id => $id,
            object_type => 'comment',
            db_data => $photo,
        })->get_image_data( num => 0, size => 'fp' );
    };
}

sub _extra_new_area_data {
    my ($row, $ref) = @_;

    if ( $ref =~ /ward|council/ ) {
        my $nearest_st = FixMyStreet::Geocode::Address->new($row->{geocode})->for_alert;
        $row->{nearest} = $nearest_st;
    }

    my $dt = $parser->parse_timestamp( $row->{confirmed} );
    FixMyStreet->set_time_zone($dt);
    $row->{confirmed} = $dt;

    # Hack in the image for the non-object reports
    my $photo = $row->{photo};
    my $id = $row->{id};
    $row->{get_first_image_fp} = sub {
        return FixMyStreet::App::Model::PhotoSet->new({
            object_id => $id,
            object_type => 'problem',
            db_data => $photo,
        })->get_image_data( num => 0, size => 'fp' );
    };
}

# Nearby done separately as more complicated joining of the two
sub send_local {
    my $rs = FixMyStreet::DB->resultset('AlertType');
    my $alert_type = $rs->find( { ref => 'local_problems' } );
    my $schema = $alert_type->result_source->schema;

    my $states = "'" . join( "', '", FixMyStreet::DB::Result::Problem::visible_states() ) . "'";
    my $reports = "select problem.id, problem.bodies_str, problem.postcode, problem.geocode, problem.confirmed, problem.cobrand,
        problem.latitude, problem.longitude, problem.title, problem.detail, problem.photo, problem.user_id
        from problem where
            problem.state in ($states)
        and problem.non_public = 'f'
        and problem.confirmed >= current_timestamp - '7 days'::interval
        order by confirmed desc";
    $reports = FixMyStreet::DB->schema->storage->dbh->prepare($reports);
    $reports->execute();
    my @reports;
    while (my $row = $reports->fetchrow_hashref) {
        $row->{lon_rad} = deg2rad($row->{longitude});
        $row->{lat_rad} = deg2rad(90 - $row->{latitude});
        my $dt = $parser->parse_timestamp( $row->{confirmed} );
        FixMyStreet->set_time_zone($dt);
        $row->{confirmed} = $dt;
        $row->{confirmed_str} = $dt->strftime('%Y-%m-%d %H:%M:%S');
        my $nearest_st = FixMyStreet::Geocode::Address->new($row->{geocode})->for_alert;
        $row->{nearest} = $nearest_st;
        my $photo = $row->{photo};
        my $id = $row->{id};
        $row->{get_first_image_fp} = sub {
            return FixMyStreet::App::Model::PhotoSet->new({
                object_id => $id,
                object_type => 'problem',
                db_data => $photo,
            })->get_image_data( num => 0, size => 'fp' );
        };
        push @reports, $row;
    }

    my $query = $schema->resultset('Alert')->search( {
        alert_type   => 'local_problems',
        whendisabled => undef,
        confirmed    => 1
    }, {
        order_by     => 'id'
    } );
    while (my $alert = $query->next) {
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($alert->cobrand)->new();
        next unless $cobrand->email_host;
        next if $alert->is_from_abuser;

        my $whensubscribed = $alert->whensubscribed->strftime('%Y-%m-%d %H:%M:%S');
        my $longitude = $alert->parameter;
        my $latitude  = $alert->parameter2;
        my $lon_rad = deg2rad($longitude);
        my $lat_rad = deg2rad(90 - $latitude);
        my $distance = $alert->parameter3;
        $distance ||= FixMyStreet::Gaze::get_radius_containing_population($latitude, $longitude);
        my %data = (
            template => $alert_type->template,
            data => [],
            alert_id => $alert->id,
            alert_user => $alert->user,
            lang => $alert->lang,
            cobrand => $cobrand,
            cobrand_data => $alert->cobrand_data,
            schema => $schema,
        );

        foreach my $row (@reports) {
            next if alert_check_cobrand($alert->cobrand, $row->{cobrand});

            # Ignore alerts created after the report was confirmed
            next if $whensubscribed gt $row->{confirmed_str};
            # Ignore alerts on reports by the same user
            next if $alert->user_id == $row->{user_id};
            # Ignore reports too far away
            next if great_circle_distance($row->{lon_rad}, $row->{lat_rad}, $lon_rad, $lat_rad, 6372.8) > $distance;
            # Ignore reports already alerted on
            next if $schema->resultset('AlertSent')->search({ alert_id => $alert->id, parameter => $row->{id} })->count;

            $schema->resultset('AlertSent')->create( {
                alert_id  => $alert->id,
                parameter => $row->{id},
            } );
            push @{$data{data}}, $row;
        }
        _send_aggregated_alert(%data) if @{$data{data}};
    }
}

sub _send_aggregated_alert(%) {
    my %data = @_;

    my $cobrand = $data{cobrand};

    $cobrand->set_lang_and_domain( $data{lang}, 1, FixMyStreet->path_to('locale')->stringify );

    my $user = $data{alert_user};

    my $alert_by = $user->alert_by($data{is_new_update}, $cobrand);
    return if $alert_by eq 'none';

    # Mark user as active as they're being sent an alert
    $user->set_last_active;
    $user->update;

    return if $data{schema}->resultset('Abuse')->check(
        $user->email_verified ? $user->email : undef,
        $user->phone_verified ? $user->phone : undef,
    );

    my $token = $data{schema}->resultset("Token")->new_result( {
        scope => 'alert',
        data  => {
            id => $data{alert_id},
            type => 'unsubscribe',
        }
    } );
    $data{unsubscribe_url} = $cobrand->base_url( $data{cobrand_data} ) . '/A/' . $token->token;

# Filter out alerts that have templated email responses for separate sending and send those to the problem reporter
    my @template_data = grep { $_->{item_private_email_text } && $_->{user_id} == $_->{alert_user_id} } @{ $data{data} };
    @{ $data{data} } = grep {! $_->{item_private_email_text } || $_->{user_id} != $_->{alert_user_id} } @{ $data{data} };

    if (@template_data) {
        my %template_data = %data;
        $template_data{data} = [@template_data];
        $template_data{private_email} = 1;
        trigger_alert_sending($alert_by, $token, %template_data);
    };

    if (@{ $data{data} }) {
        trigger_alert_sending($alert_by, $token, %data);
    }

}

sub trigger_alert_sending {
    my $alert_by = shift;
    my $token = shift;
    my %data = @_;

    my $result;
    if ($alert_by eq 'phone') {
        $result = _send_aggregated_alert_phone(%data);
    } else {
        $result = _send_aggregated_alert_email(%data);
    }

    if ($result->{success}) {
        $token->insert();
    } else {
        warn "Failed to send alert $data{alert_id}: $result->{error}";
    }
}

sub _send_aggregated_alert_email {
    my %data = @_;

    my $cobrand = $data{cobrand};

    FixMyStreet::Map::set_map_class($cobrand);
    my $sender = FixMyStreet::Email::unique_verp_id([ 'alert', $data{alert_id} ], $cobrand->call_hook('verp_email_domain'));
    my $result = FixMyStreet::Email::send_cron(
        $data{schema},
        "$data{template}.txt",
        \%data,
        {
            To => $data{alert_user}->email,
        },
        $sender,
        0,
        $cobrand,
        $data{lang}
    );

    unless ($result) {
        return { success => 1 };
    } else {
        return { error => "failed to send email" };
    }
}

sub _send_aggregated_alert_phone {
    my %data = @_;
    my $result = FixMyStreet::SMS->new(cobrand => $data{cobrand})->send(
        to => $data{alert_user}->phone,
        body => sprintf(_("Your report (%d) has had an update; to view: %s\n\nTo stop: %s"), $data{id}, $data{problem_url}, $data{unsubscribe_url}),
    );
    return $result;
}

# Ignore TfL reports if the alert wasn't set up on TfL, and similar
sub alert_check_cobrand {
    my ($alert_cobrand, $item_cobrand) = @_;
    return 1 if $alert_cobrand ne 'tfl' && $item_cobrand eq 'tfl';
    return 1 if $alert_cobrand eq 'highwaysengland' && $item_cobrand ne 'highwaysengland';
    return 1 if $alert_cobrand eq 'cyclinguk' && $item_cobrand ne 'cyclinguk';
    return 0;
}

1;
