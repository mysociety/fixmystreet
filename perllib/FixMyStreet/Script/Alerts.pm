package FixMyStreet::Script::Alerts;

use strict;
use warnings;

use DateTime::Format::Pg;
use IO::String;

use FixMyStreet::Gaze;
use mySociety::Locale;
use FixMyStreet::MapIt;
use RABX;

use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use FixMyStreet::Email;
use FixMyStreet::Map;
use FixMyStreet::App::Model::PhotoSet;

my $parser = DateTime::Format::Pg->new();

# Child must have confirmed, id, email, state(!) columns
# If parent/child, child table must also have name and text
#   and foreign key to parent must be PARENT_id
sub send() {
    my $rs = FixMyStreet::DB->resultset('AlertType');
    my $schema = $rs->result_source->schema;

    my $q = $rs->search( { ref => { -not_like => '%local_problems%' } } );
    while (my $alert_type = $q->next) {
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
                   $item_table.cobrand as item_cobrand,
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
        my $last_problem_state = '';
        my %data = ( template => $alert_type->template, data => [], schema => $schema );
        while (my $row = $query->fetchrow_hashref) {

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

            next if $row->{alert_cobrand} ne 'tfl' && $row->{item_cobrand} eq 'tfl';

            $schema->resultset('AlertSent')->create( {
                alert_id  => $row->{alert_id},
                parameter => $row->{item_id},
            } );

            # this is currently only for new_updates
            if (defined($row->{item_text})) {
                # this might throw up the odd false positive but only in cases where the
                # state has changed and there was already update text
                if ($row->{item_problem_state} &&
                    !( $last_problem_state eq '' && $row->{item_problem_state} eq 'confirmed' ) &&
                    $last_problem_state ne $row->{item_problem_state}
                ) {
                    my $state = FixMyStreet::DB->resultset("State")->display($row->{item_problem_state}, 1, $cobrand->moniker);

                    my $update = _('State changed to:') . ' ' . $state;
                    $row->{item_text} = $row->{item_text} ? $row->{item_text} . "\n\n" . $update :
                                                            $update;
                }
                next unless $row->{item_text};
            }

            if ($last_alert_id && $last_alert_id != $row->{alert_id}) {
                $last_problem_state = '';
                _send_aggregated_alert_email(%data);
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
                    # Get a report object for its photo and static map
                    $data{report} = $schema->resultset('Problem')->find({ id => $row->{id} });
                }
            }

            my $url = $cobrand->base_url_for_report($row);
            # this is currently only for new_updates
            if (defined($row->{item_text})) {
                if ( $cobrand->moniker ne 'zurich' && $row->{alert_user_id} == $row->{user_id} ) {
                    # This is an alert to the same user who made the report - make this a login link
                    # Don't bother with Zurich which has no accounts
                    my $user = $schema->resultset('User')->find( {
                        id => $row->{alert_user_id}
                    } );
                    $data{alert_user} = $user;
                    my $token_obj = $schema->resultset('Token')->create( {
                        scope => 'alert_to_reporter',
                        data  => {
                            id => $row->{id},
                        }
                    } );
                    $data{problem_url} = $url . "/R/" . $token_obj->token;

                    # Also record timestamp on report if it's an update about being fixed...
                    if (FixMyStreet::DB::Result::Problem::fixed_states()->{$row->{state}} || FixMyStreet::DB::Result::Problem::closed_states()->{$row->{state}}) {
                        $data{report}->set_extra_metadata_if_undefined('closure_alert_sent_at', time());
                        $data{report}->update;
                    }
                } else {
                    $data{problem_url} = $url . "/report/" . $row->{id};
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
                $row->{get_first_image_fp} = sub {
                    return FixMyStreet::App::Model::PhotoSet->new({
                        db_data => $row->{item_photo},
                    })->get_image_data( num => 0, size => 'fp' );
                };

            # this is ward and council problems
            } else {
                if ( exists $row->{geocode} && $row->{geocode} && $ref =~ /ward|council/ ) {
                    my $nearest_st = _get_address_from_geocode( $row->{geocode} );
                    $row->{nearest} = $nearest_st;
                }

                my $dt = $parser->parse_timestamp( $row->{confirmed} );
                FixMyStreet->set_time_zone($dt);
                $row->{confirmed} = $dt;

                # Hack in the image for the non-object reports
                $row->{get_first_image_fp} = sub {
                    return FixMyStreet::App::Model::PhotoSet->new({
                        db_data => $row->{photo},
                    })->get_image_data( num => 0, size => 'fp' );
                };
            }

            push @{$data{data}}, $row;

            if (!$data{alert_user_id}) {
                %data = (%data, %$row);
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
            _send_aggregated_alert_email(%data);
        }
    }

    # Nearby done separately as the table contains the parameters
    my $template = $rs->find( { ref => 'local_problems' } )->template;
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

        my $longitude = $alert->parameter;
        my $latitude  = $alert->parameter2;
        my $d = FixMyStreet::Gaze::get_radius_containing_population($latitude, $longitude);
        # Convert integer to GB locale string (with a ".")
        $d = mySociety::Locale::in_gb_locale {
            sprintf("%f", $d);
        };
        my $states = "'" . join( "', '", FixMyStreet::DB::Result::Problem::visible_states() ) . "'";
        my %data = (
            template => $template,
            data => [],
            alert_id => $alert->id,
            alert_user => $alert->user,
            lang => $alert->lang,
            cobrand => $cobrand,
            cobrand_data => $alert->cobrand_data,
            schema => $schema,
        );
        my $q = "select problem.id, problem.bodies_str, problem.postcode, problem.geocode, problem.confirmed, problem.cobrand,
            problem.title, problem.detail, problem.photo from problem_find_nearby(?, ?, ?) as nearby, problem, users
            where nearby.problem_id = problem.id
            and problem.user_id = users.id
            and problem.state in ($states)
            and problem.non_public = 'f'
            and problem.confirmed >= ? and problem.confirmed >= current_timestamp - '7 days'::interval
            and (select whenqueued from alert_sent where alert_sent.alert_id = ? and alert_sent.parameter::integer = problem.id) is null
            and users.email <> ?
            order by confirmed desc";
        $q = FixMyStreet::DB->schema->storage->dbh->prepare($q);
        $q->execute($latitude, $longitude, $d, $alert->whensubscribed, $alert->id, $alert->user->email);
        while (my $row = $q->fetchrow_hashref) {
            next if $alert->cobrand ne 'tfl' && $row->{cobrand} eq 'tfl';

            $schema->resultset('AlertSent')->create( {
                alert_id  => $alert->id,
                parameter => $row->{id},
            } );
            if ( exists $row->{geocode} && $row->{geocode} ) {
                my $nearest_st = _get_address_from_geocode( $row->{geocode} );
                $row->{nearest} = $nearest_st;
            }
            my $dt = $parser->parse_timestamp( $row->{confirmed} );
            FixMyStreet->set_time_zone($dt);
            $row->{confirmed} = $dt;
            $row->{get_first_image_fp} = sub {
                return FixMyStreet::App::Model::PhotoSet->new({
                    db_data => $row->{photo},
                })->get_image_data( num => 0, size => 'fp' );
            };
            push @{$data{data}}, $row;
        }
        _send_aggregated_alert_email(%data) if @{$data{data}};
    }
}

sub _send_aggregated_alert_email(%) {
    my %data = @_;

    my $cobrand = $data{cobrand};

    $cobrand->set_lang_and_domain( $data{lang}, 1, FixMyStreet->path_to('locale')->stringify );
    FixMyStreet::Map::set_map_class($cobrand->map_type);

    if (!$data{alert_user}) {
        my $user = $data{schema}->resultset('User')->find( {
            id => $data{alert_user_id}
        } );
        $data{alert_user} = $user;
    }

    # Ignore phone-only users
    return unless $data{alert_user}->email_verified;

    my $email = $data{alert_user}->email;
    my ($domain) = $email =~ m{ @ (.*) \z }x;
    return if $data{schema}->resultset('Abuse')->search( {
        email => [ $email, $domain ]
    } )->first;

    my $token = $data{schema}->resultset("Token")->new_result( {
        scope => 'alert',
        data  => {
            id => $data{alert_id},
            type => 'unsubscribe',
            email => $email,
        }
    } );
    $data{unsubscribe_url} = $cobrand->base_url( $data{cobrand_data} ) . '/A/' . $token->token;

    my $sender = FixMyStreet::Email::unique_verp_id('alert', $data{alert_id});
    my $result = FixMyStreet::Email::send_cron(
        $data{schema},
        "$data{template}.txt",
        \%data,
        {
            To => $email,
        },
        $sender,
        0,
        $cobrand,
        $data{lang}
    );

    unless ($result) {
        $token->insert();
    } else {
        print "Failed to send alert $data{alert_id}!";
    }
}

sub _get_address_from_geocode {
    my $geocode = shift;

    return '' unless defined $geocode;
    my $h = new IO::String($geocode);
    my $data = RABX::wire_rd($h);

    my $str = '';

    my $address = $data->{resourceSets}[0]{resources}[0]{address};
    my @address;
    push @address, $address->{addressLine} if $address->{addressLine} && $address->{addressLine} ne 'Street';
    push @address, $address->{locality} if $address->{locality};
    $str .= sprintf(_("Nearest road to the pin placed on the map (automatically generated by Bing Maps): %s\n\n"),
        join( ', ', @address ) ) if @address;

    return $str;
}

1;
