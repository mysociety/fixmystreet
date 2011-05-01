#!/usr/bin/perl -w
#
# FixMyStreet::Alert.pm
# Alerts by email or RSS.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Alert.pm,v 1.71 2010-01-06 16:50:27 louise Exp $

package FixMyStreet::Alert::Error;

use Error qw(:try);

@FixMyStreet::Alert::Error::ISA = qw(Error::Simple);

package FixMyStreet::Alert;

use strict;
use Error qw(:try);
use File::Slurp;
use FindBin;
use POSIX qw(strftime);
use XML::RSS;

use Cobrand;
use mySociety::AuthToken;
use mySociety::Config;
use mySociety::DBHandle qw(dbh);
use mySociety::Email;
use mySociety::EmailUtil;
use mySociety::Gaze;
use mySociety::Locale;
use mySociety::MaPit;
use mySociety::Random qw(random_bytes);
use mySociety::Sundries qw(ordinal);
use mySociety::Web qw(ent);

# Add a new alert
sub create ($$$$;@) {
    my ($email, $alert_type, $cobrand, $cobrand_data, @params) = @_;
    my $already = 0;
    if (0==@params) {
        ($already) = dbh()->selectrow_array('select id from alert where alert_type=? and email=? limit 1',
            {}, $alert_type, $email);
    } elsif (1==@params) {
        ($already) = dbh()->selectrow_array('select id from alert where alert_type=? and email=? and parameter=? limit 1',
            {}, $alert_type, $email, @params);
    } elsif (2==@params) {
        ($already) = dbh()->selectrow_array('select id from alert where alert_type=? and email=? and parameter=? and parameter2=? limit 1',
            {}, $alert_type, $email, @params);
    }
    return $already if $already;

    my $id = dbh()->selectrow_array("select nextval('alert_id_seq');");
    my $lang = $mySociety::Locale::lang;
    if (0==@params) {
        dbh()->do('insert into alert (id, alert_type, email, lang, cobrand, cobrand_data)
            values (?, ?, ?, ?, ?, ?)', {}, $id, $alert_type, $email, $lang, $cobrand, $cobrand_data);
    } elsif (1==@params) {
        dbh()->do('insert into alert (id, alert_type, parameter, email, lang, cobrand, cobrand_data)
            values (?, ?, ?, ?, ?, ?, ?)', {}, $id, $alert_type, @params, $email, $lang, $cobrand, $cobrand_data);
    } elsif (2==@params) {
        dbh()->do('insert into alert (id, alert_type, parameter, parameter2, email, lang, cobrand, cobrand_data)
            values (?, ?, ?, ?, ?, ?, ?, ?)', {}, $id, $alert_type, @params, $email, $lang, $cobrand, $cobrand_data);
    }
    dbh()->commit();
    return $id;
}

sub confirm ($) {
    my $id = shift;
    dbh()->do("update alert set confirmed=1, whendisabled=null where id=?", {}, $id);
    dbh()->commit();
}

# Delete an alert
sub delete ($) {
    my $id = shift;
    dbh()->do('update alert set whendisabled = ms_current_timestamp() where id = ?', {}, $id);
    dbh()->commit();
}

# This makes load of assumptions, but still should be useful
# 
# Child must have confirmed, id, email, state(!) columns
# If parent/child, child table must also have name and text
#   and foreign key to parent must be PARENT_id

sub email_alerts ($) {
    my ($testing_email) = @_;
    my $url; 
    my $q = dbh()->prepare("select * from alert_type where ref not like '%local_problems%'");
    $q->execute();
    my $testing_email_clause = '';
    while (my $alert_type = $q->fetchrow_hashref) {
        my $ref = $alert_type->{ref};
        my $head_table = $alert_type->{head_table};
        my $item_table = $alert_type->{item_table};
        my $testing_email_clause = "and $item_table.email <> '$testing_email'" if $testing_email;
        my $query = 'select alert.id as alert_id, alert.email as alert_email, alert.lang as alert_lang, alert.cobrand as alert_cobrand,
            alert.cobrand_data as alert_cobrand_data, alert.parameter as alert_parameter, alert.parameter2 as alert_parameter2, ';
        if ($head_table) {
            $query .= "
                   $item_table.id as item_id, $item_table.name as item_name, $item_table.text as item_text,
                   $head_table.*
            from alert
                inner join $item_table on alert.parameter::integer = $item_table.${head_table}_id
                inner join $head_table on alert.parameter::integer = $head_table.id";
        } else {
            $query .= " $item_table.*,
                   $item_table.id as item_id
            from alert, $item_table";
        }
        $query .= "
            where alert_type='$ref' and whendisabled is null and $item_table.confirmed >= whensubscribed
            and $item_table.confirmed >= ms_current_timestamp() - '7 days'::interval
             and (select whenqueued from alert_sent where alert_sent.alert_id = alert.id and alert_sent.parameter::integer = $item_table.id) is null
            and $item_table.email <> alert.email 
            $testing_email_clause
            and $alert_type->{item_where}
            and alert.confirmed = 1
            order by alert.id, $item_table.confirmed";
        # XXX Ugh - needs work
        $query =~ s/\?/alert.parameter/ if ($query =~ /\?/);
        $query =~ s/\?/alert.parameter2/ if ($query =~ /\?/);
        $query = dbh()->prepare($query);
        $query->execute();
        my $last_alert_id;
        my %data = ( template => $alert_type->{template}, data => '' );
        while (my $row = $query->fetchrow_hashref) {
            # Cobranded and non-cobranded messages can share a database. In this case, the conf file 
            # should specify a vhost to send the reports for each cobrand, so that they don't get sent 
            # more than once if there are multiple vhosts running off the same database. The email_host
            # call checks if this is the host that sends mail for this cobrand.
            next unless (Cobrand::email_host($row->{alert_cobrand}));

            dbh()->do('insert into alert_sent (alert_id, parameter) values (?,?)', {}, $row->{alert_id}, $row->{item_id});
            if ($last_alert_id && $last_alert_id != $row->{alert_id}) {
                _send_aggregated_alert_email(%data);
                %data = ( template => $alert_type->{template}, data => '' );
            }

            # create problem status message for the templates
            $data{state_message} =
              $row->{state} eq 'fixed'
              ? _("This report is currently marked as fixed.")
              : _("This report is currently marked as open.");

            $url = Cobrand::base_url_for_emails($row->{alert_cobrand}, $row->{alert_cobrand_data});
            if ($row->{item_text}) {
                $data{problem_url} = $url . "/report/" . $row->{id};
                $data{data} .= $row->{item_name} . ' : ' if $row->{item_name};
                $data{data} .= $row->{item_text} . "\n\n------\n\n";
            } else {
                $data{data} .= $url . "/report/" . $row->{id} . " - $row->{title}\n\n";
            }
            if (!$data{alert_email}) {
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
    my $template = dbh()->selectrow_array("select template from alert_type where ref = 'local_problems'");
    my $query = "select * from alert where alert_type='local_problems' and whendisabled is null and confirmed=1 order by id";
    $query = dbh()->prepare($query);
    $query->execute();
    while (my $alert = $query->fetchrow_hashref) {
        next unless (Cobrand::email_host($alert->{cobrand}));
        my $longitude = $alert->{parameter};
        my $latitude  = $alert->{parameter2};
        $url = Cobrand::base_url_for_emails($alert->{cobrand}, $alert->{cobrand_data});
        my ($site_restriction, $site_id) = Cobrand::site_restriction($alert->{cobrand}, $alert->{cobrand_data});
        my $d = mySociety::Gaze::get_radius_containing_population($latitude, $longitude, 200000);
        # Convert integer to GB locale string (with a ".")
        $d = mySociety::Locale::in_gb_locale {
            sprintf("%f", int($d*10+0.5)/10);
        };
        my $testing_email_clause = "and problem.email <> '$testing_email'" if $testing_email;        
        my %data = ( template => $template, data => '', alert_id => $alert->{id}, alert_email => $alert->{email}, lang => $alert->{lang}, cobrand => $alert->{cobrand}, cobrand_data => $alert->{cobrand_data} );
        my $q = "select * from problem_find_nearby(?, ?, ?) as nearby, problem
            where nearby.problem_id = problem.id and problem.state in ('confirmed', 'fixed')
            and problem.confirmed >= ? and problem.confirmed >= ms_current_timestamp() - '7 days'::interval
            and (select whenqueued from alert_sent where alert_sent.alert_id = ? and alert_sent.parameter::integer = problem.id) is null
            and problem.email <> ?
            $testing_email_clause
            $site_restriction
            order by confirmed desc";
        $q = dbh()->prepare($q);
        $q->execute($latitude, $longitude, $d, $alert->{whensubscribed}, $alert->{id}, $alert->{email});
        while (my $row = $q->fetchrow_hashref) {
            dbh()->do('insert into alert_sent (alert_id, parameter) values (?,?)', {}, $alert->{id}, $row->{id});
            $data{data} .= $url . "/report/" . $row->{id} . " - $row->{title}\n\n";
        }
        _send_aggregated_alert_email(%data) if $data{data};
    }
}

sub _send_aggregated_alert_email(%) {
    my %data = @_;
    Cobrand::set_lang_and_domain($data{cobrand}, $data{lang}, 1);

    $data{unsubscribe_url} = Cobrand::base_url_for_emails($data{cobrand}, $data{cobrand_data}) . '/A/'
        . mySociety::AuthToken::store('alert', { id => $data{alert_id}, type => 'unsubscribe', email => $data{alert_email} } );
    my $template = "$FindBin::Bin/../templates/emails/$data{template}";
    if ($data{cobrand}) {
        my $template_cobrand = "$FindBin::Bin/../templates/emails/$data{cobrand}/$data{template}";
        $template = $template_cobrand if -e $template_cobrand;
    }
    $template = File::Slurp::read_file($template);
    my $sender = Cobrand::contact_email($data{cobrand});
    my $sender_name = Cobrand::contact_name($data{cobrand});
    (my $from = $sender) =~ s/team/fms-DO-NOT-REPLY/; # XXX
    my $email = mySociety::Email::construct_email({
        _template_ => _($template),
        _parameters_ => \%data,
        From => [ $from, _($sender_name) ],
        To => $data{alert_email},
        'Message-ID' => sprintf('<alert-%s-%s@mysociety.org>', time(), unpack('h*', random_bytes(5, 1))),
    });

    my $result = mySociety::EmailUtil::send_email($email, $sender, $data{alert_email});
    if ($result == mySociety::EmailUtil::EMAIL_SUCCESS) {
        dbh()->commit();
    } else {
        dbh()->rollback();
        throw FixMyStreet::Alert::Error("Failed to send alert $data{alert_id}!");
    }
}

sub generate_rss ($$$;$$$$$) {
    my ($type, $xsl, $qs, $db_params, $title_params, $cobrand, $http_q,
        $db_criteria) = @_;
    $db_params ||= [];
    my $url = Cobrand::base_url($cobrand);
    my $cobrand_data = Cobrand::extra_data($cobrand, $http_q);
    my $q = dbh()->prepare('select * from alert_type where ref=?');
    $q->execute($type);
    my $alert_type = $q->fetchrow_hashref;
    my ($site_restriction, $site_id) = Cobrand::site_restriction($cobrand, $cobrand_data);
    throw FixMyStreet::Alert::Error('Unknown alert type') unless $alert_type;

    # Do our own encoding
    my $rss = new XML::RSS( version => '2.0', encoding => 'UTF-8',
        stylesheet=> $xsl, encode_output => undef );
    $rss->add_module(prefix=>'georss', uri=>'http://www.georss.org/georss');

    # Only apply a site restriction if the alert uses the problem table
    $site_restriction = '' unless $alert_type->{item_table} eq 'problem';
    my $query = 'select * from ' . $alert_type->{item_table} . ' where '
        . ($alert_type->{head_table} ? $alert_type->{head_table}.'_id=? and ' : '')
        . $alert_type->{item_where} . $site_restriction
        . ($db_criteria ? $db_criteria : '')
        . ' order by ' . $alert_type->{item_order};
    my $rss_limit = mySociety::Config::get('RSS_LIMIT');
    $query .= " limit $rss_limit" unless $type =~ /^all/;
    $q = dbh()->prepare($query);
    if ($query =~ /\?/) {
        throw FixMyStreet::Alert::Error('Missing parameter') unless @$db_params;
        $q->execute(@$db_params);
    } else {
        $q->execute();
    }

    while (my $row = $q->fetchrow_hashref) {

        $row->{name} ||= 'anonymous';

        my $pubDate;
        if ($row->{confirmed}) {
            $row->{confirmed} =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/;
            $pubDate = mySociety::Locale::in_gb_locale {
                strftime("%a, %d %b %Y %H:%M:%S %z", $6, $5, $4, $3, $2-1, $1-1900, -1, -1, 0)
            };
            $row->{confirmed} = strftime("%e %B", $6, $5, $4, $3, $2-1, $1-1900, -1, -1, 0);
            $row->{confirmed} =~ s/^\s+//;
            $row->{confirmed} =~ s/^(\d+)/ordinal($1)/e if $mySociety::Locale::lang eq 'en-gb';
        }

        (my $title = _($alert_type->{item_title})) =~ s/{{(.*?)}}/$row->{$1}/g;
        (my $link = $alert_type->{item_link}) =~ s/{{(.*?)}}/$row->{$1}/g;
        (my $desc = _($alert_type->{item_description})) =~ s/{{(.*?)}}/$row->{$1}/g;
        my $cobrand_url = Cobrand::url($cobrand, $url . $link, $http_q);
        my %item = (
            title => ent($title),
            link => $cobrand_url,
            guid => $cobrand_url,
            description => ent(ent($desc)) # Yes, double-encoded, really.
        );
        $item{pubDate} = $pubDate if $pubDate;
        $item{category} = $row->{category} if $row->{category};

        my $display_photos = Cobrand::allow_photo_display($cobrand);    
        if ($display_photos && $row->{photo}) {
            $item{description} .= ent("\n<br><img src=\"". Cobrand::url($cobrand, $url, $http_q) . "/photo?id=$row->{id}\">");
        }
        my $recipient_name = Cobrand::contact_name($cobrand);
        $item{description} .= ent("\n<br><a href='$cobrand_url'>" .
            sprintf(_("Report on %s"), $recipient_name) . "</a>");

        if ($row->{latitude} || $row->{longitude}) {
            $item{georss} = { point => "$row->{latitude} $row->{longitude}" };
        }
        $rss->add_item( %item );
    }

    my $row = {};
    if ($alert_type->{head_sql_query}) {
        $q = dbh()->prepare($alert_type->{head_sql_query});
        if ($alert_type->{head_sql_query} =~ /\?/) {
            $q->execute(@$db_params);
        } else {
            $q->execute();
        }
        $row = $q->fetchrow_hashref;
    }
    foreach (keys %$title_params) {
        $row->{$_} = $title_params->{$_};
    }
    (my $title = _($alert_type->{head_title})) =~ s/{{(.*?)}}/$row->{$1}/g;
    (my $link = $alert_type->{head_link}) =~ s/{{(.*?)}}/$row->{$1}/g;
    (my $desc = _($alert_type->{head_description})) =~ s/{{(.*?)}}/$row->{$1}/g;
    $rss->channel(
        title => ent($title), link =>  "$url$link$qs", description  => ent($desc),
        language   => 'en-gb'
    );

    my $out = $rss->as_string;
    my $uri = Cobrand::url($cobrand, $ENV{SCRIPT_URI}, $http_q);
    $out =~ s{<link>(.*?)</link>}{"<link>" . Cobrand::url($cobrand, $1, $http_q) . "</link><uri>$uri</uri>"}e;
             
    return $out;
}
