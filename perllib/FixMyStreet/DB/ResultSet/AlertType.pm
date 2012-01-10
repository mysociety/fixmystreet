package FixMyStreet::DB::ResultSet::AlertType;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

use mySociety::DBHandle qw(dbh);
use mySociety::EmailUtil;
use mySociety::Gaze;
use mySociety::Locale;
use mySociety::MaPit;
use IO::String;
use RABX;

# Child must have confirmed, id, email, state(!) columns
# If parent/child, child table must also have name and text
#   and foreign key to parent must be PARENT_id
sub email_alerts ($) {
    my ( $rs ) = @_;

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
                   $head_table.*
            from alert
                inner join $item_table on alert.parameter::integer = $item_table.${head_table}_id
                inner join $head_table on alert.parameter::integer = $head_table.id
                ";
        } else {
            $query .= " $item_table.*,
                   $item_table.id as item_id
            from alert, $item_table";
        }
        $query .= "
            where alert_type='$ref' and whendisabled is null and $item_table.confirmed >= whensubscribed
            and $item_table.confirmed >= ms_current_timestamp() - '7 days'::interval
             and (select whenqueued from alert_sent where alert_sent.alert_id = alert.id and alert_sent.parameter::integer = $item_table.id) is null
            and $item_table.user_id <> alert.user_id
            and " . $alert_type->item_where . "
            and alert.confirmed = 1
            order by alert.id, $item_table.confirmed";
        # XXX Ugh - needs work
        $query =~ s/\?/alert.parameter/ if ($query =~ /\?/);
        $query =~ s/\?/alert.parameter2/ if ($query =~ /\?/);

        $query = dbh()->prepare($query);
        $query->execute();
        my $last_alert_id;
        my %data = ( template => $alert_type->template, data => '' );
        while (my $row = $query->fetchrow_hashref) {

            my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($row->{alert_cobrand})->new();

            # Cobranded and non-cobranded messages can share a database. In this case, the conf file 
            # should specify a vhost to send the reports for each cobrand, so that they don't get sent 
            # more than once if there are multiple vhosts running off the same database. The email_host
            # call checks if this is the host that sends mail for this cobrand.
            next unless $cobrand->email_host;

            FixMyStreet::App->model('DB::AlertSent')->create( {
                alert_id  => $row->{alert_id},
                parameter => $row->{item_id},
            } );
            if ($last_alert_id && $last_alert_id != $row->{alert_id}) {
                _send_aggregated_alert_email(%data);
                %data = ( template => $alert_type->template, data => '' );
            }

            # create problem status message for the templates
            if ( FixMyStreet::DB::Result::Problem::fixed_states()->{$row->{state}} ) {
                $data{state_message} = _("This report is currently marked as fixed.");
            } elsif ( FixMyStreet::DB::Result::Problem::closed_states()->{$row->{state}} ) {
                $data{state_message} = _("This report is currently marked as closed.")
            } else {
                $data{state_message} = _("This report is currently marked as open.");
            }

            my $url = $cobrand->base_url_for_emails( $row->{alert_cobrand_data} );
            # this is currently only for new_updates
            if ($row->{item_text}) {
                $data{problem_url} = $url . "/report/" . $row->{id};
                $data{data} .= $row->{item_name} . ' : ' if $row->{item_name} && !$row->{item_anonymous};
                $data{data} .= $row->{item_text} . "\n\n------\n\n";
            # this is ward and council problems
            } else {
                my $postcode = $cobrand->format_postcode( $row->{postcode} );
                $postcode = ", $postcode" if $postcode;
                $data{data} .= $url . "/report/" . $row->{id} . " - $row->{title}$postcode\n\n";
                if ( exists $row->{geocode} && $row->{geocode} && $ref =~ /ward|council/ ) {
                    my $nearest_st = _get_address_from_gecode( $row->{geocode} );
                    $data{data} .= $nearest_st if $nearest_st;
                }
                $data{data} .= "\n\n------\n\n";
            }
            if (!$data{alert_user_id}) {
                %data = (%data, %$row);
                if ($ref eq 'area_problems' || $ref eq 'council_problems' || $ref eq 'ward_problems') {
                    my $va_info = mySociety::MaPit::call('area', $row->{alert_parameter});
                    $data{area_name} = $va_info->{name};
                }
                if ($ref eq 'ward_problems') {
                    my $va_info = mySociety::MaPit::call('area', $row->{alert_parameter2});
                    $data{ward_name} = $va_info->{name};
                }
            }
            $data{cobrand} = $row->{alert_cobrand};
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
    my $query = FixMyStreet::App->model('DB::Alert')->search( {
        alert_type   => 'local_problems',
        whendisabled => undef,
        confirmed    => 1
    }, {
        order_by     => 'id'
    } );
    while (my $alert = $query->next) {
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($alert->cobrand)->new();
        next unless $cobrand->email_host;

        my $longitude = $alert->parameter;
        my $latitude  = $alert->parameter2;
        my $url = $cobrand->base_url_for_emails( $alert->cobrand_data );
        my ($site_restriction, $site_id) = $cobrand->site_restriction( $alert->cobrand_data );
        my $d = mySociety::Gaze::get_radius_containing_population($latitude, $longitude, 200000);
        # Convert integer to GB locale string (with a ".")
        $d = mySociety::Locale::in_gb_locale {
            sprintf("%f", int($d*10+0.5)/10);
        };
        my $states = "'" . join( "', '", FixMyStreet::DB::Result::Problem::visible_states() ) . "'";
        my %data = ( template => $template, data => '', alert_id => $alert->id, alert_email => $alert->user->email, lang => $alert->lang, cobrand => $alert->cobrand, cobrand_data => $alert->cobrand_data );
        my $q = "select problem.id, problem.postcode, problem.geocode, problem.title from problem_find_nearby(?, ?, ?) as nearby, problem, users
            where nearby.problem_id = problem.id
            and problem.user_id = users.id
            and problem.state in ($states)
            and problem.confirmed >= ? and problem.confirmed >= ms_current_timestamp() - '7 days'::interval
            and (select whenqueued from alert_sent where alert_sent.alert_id = ? and alert_sent.parameter::integer = problem.id) is null
            and users.email <> ?
            $site_restriction
            order by confirmed desc";
        $q = dbh()->prepare($q);
        $q->execute($latitude, $longitude, $d, $alert->whensubscribed, $alert->id, $alert->user->email);
        while (my $row = $q->fetchrow_hashref) {
            FixMyStreet::App->model('DB::AlertSent')->create( {
                alert_id  => $alert->id,
                parameter => $row->{id},
            } );
            my $postcode = $cobrand->format_postcode( $row->{postcode} );
            $postcode = ", $postcode" if $postcode;
            $data{data} .= $url . "/report/" . $row->{id} . " - $row->{title}$postcode\n\n";
            if ( exists $row->{geocode} && $row->{geocode} ) {
                my $nearest_st = _get_address_from_gecode( $row->{geocode} );
                $data{data} .= $nearest_st if $nearest_st;
            }
            $data{data} .= "\n\n------\n\n";
        }
        _send_aggregated_alert_email(%data) if $data{data};
    }
}

sub _send_aggregated_alert_email(%) {
    my %data = @_;

    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($data{cobrand})->new();

    $cobrand->set_lang_and_domain( $data{lang}, 1 );

    if (!$data{alert_email}) {
        my $user = FixMyStreet::App->model('DB::User')->find( {
            id => $data{alert_user_id}
        } );
        $data{alert_email} = $user->email;
    }

    my $token = FixMyStreet::App->model("DB::Token")->new_result( {
        scope => 'alert',
        data  => {
            id => $data{alert_id},
            type => 'unsubscribe',
            email => $data{alert_email},
        }
    } );
    $data{unsubscribe_url} = $cobrand->base_url_for_emails( $data{cobrand_data} ) . '/A/' . $token->token;

    my $template = FixMyStreet->path_to(
        "templates", "email", $cobrand->moniker, $data{lang}, "$data{template}.txt"
    )->stringify;
    $template = FixMyStreet->path_to( "templates", "email", $cobrand->moniker, "$data{template}.txt" )->stringify
        unless -e $template;
    $template = FixMyStreet->path_to( "templates", "email", "default", "$data{template}.txt" )->stringify
        unless -e $template;
    $template = Utils::read_file($template);

    my $sender = $cobrand->contact_email;
    (my $from = $sender) =~ s/team/fms-DO-NOT-REPLY/; # XXX
    my $result = FixMyStreet::App->send_email_cron(
        {
            _template_ => $template,
            _parameters_ => \%data,
            From => [ $from, _($cobrand->contact_name) ],
            To => $data{alert_email},
        },
        $sender,
        [ $data{alert_email} ],
        0,
    );

    if ($result == mySociety::EmailUtil::EMAIL_SUCCESS) {
        $token->insert();
    } else {
        print "Failed to send alert $data{alert_id}!";
    }
}

sub _get_address_from_gecode {
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
