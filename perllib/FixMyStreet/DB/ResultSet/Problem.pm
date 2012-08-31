package FixMyStreet::DB::ResultSet::Problem;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

use CronFns;

use Utils;
use mySociety::Config;
use mySociety::EmailUtil;
use mySociety::MaPit;

use FixMyStreet::App;
use FixMyStreet::SendReport;

my $site_key;

sub set_restriction {
    my ( $rs, $key ) = @_;
    $site_key = $key;
}

# Front page statistics

sub recent_fixed {
    my $rs = shift;
    my $key = "recent_fixed:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = $rs->search( {
            state => [ FixMyStreet::DB::Result::Problem->fixed_states() ],
            lastupdate => { '>', \"current_timestamp-'1 month'::interval" },
        } )->count;
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub number_comments {
    my $rs = shift;
    my $key = "number_comments:$site_key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = $rs->search(
            { 'comments.state' => 'confirmed' },
            { join => 'comments' }
        )->count;
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub recent_new {
    my ( $rs, $interval ) = @_;
    (my $key = $interval) =~ s/\s+//g;
    $key = "recent_new:$site_key:$key";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = $rs->search( {
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
            confirmed => { '>', \"current_timestamp-'$interval'::interval" },
        } )->count;
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

# Front page recent lists

sub recent {
    my ( $rs ) = @_;
    return _recent( $rs, 5 );
}

sub recent_photos {
    my ( $rs, $num, $lat, $lon, $dist ) = @_;
    return _recent( $rs, $num, $lat, $lon, $dist, 1);
}

sub _recent {
    my ( $rs, $num, $lat, $lon, $dist, $photos ) = @_;

    my $key = $photos ? 'recent_photos' : 'recent';
    $key .= ":$site_key:$num";

    my $query = {
        non_public => 0,
        state      => [ FixMyStreet::DB::Result::Problem->visible_states() ],
    };
    $query->{photo} = { '!=', undef } if $photos;

    my $attrs = {
        columns => [ 'id', 'title', 'confirmed' ],
        order_by => { -desc => 'confirmed' },
        rows => $num,
    };

    my $probs;
    my $new = 0;
    if (defined $lat) {
        my $dist2 = $dist; # Create a copy of the variable to stop it being stringified into a locale in the next line!
        $key .= ":$lat:$lon:$dist2";
        $probs = Memcached::get($key);
        unless ($probs) {
            $attrs->{bind} = [ $lat, $lon, $dist ];
            $attrs->{join} = 'nearby';
            $probs = [ mySociety::Locale::in_gb_locale {
                $rs->search( $query, $attrs )->all;
            } ];
            $new = 1;
        }
    } else {
        $probs = Memcached::get($key);
        unless ($probs) {
            $probs = [ $rs->search( $query, $attrs )->all ];
            $new = 1;
        }
    }

    if ( $new ) {
        Memcached::set($key, $probs, 3600);
    } else {
        # Need to reattach schema so that confirmed column gets reinflated.
        $probs->[0]->result_source->schema( $rs->result_source->schema ) if $probs->[0];
    }

    return $probs;
}

# Problems around a location

sub around_map {
    my ( $rs, $min_lat, $max_lat, $min_lon, $max_lon, $interval, $limit ) = @_;
    my $attr = {
        order_by => { -desc => 'created' },
        columns => [
            'id', 'title', 'latitude', 'longitude', 'state', 'confirmed',
            { photo => 'photo is not null' },
        ],
    };
    $attr->{rows} = $limit if $limit;

    my $q = {
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
            latitude => { '>=', $min_lat, '<', $max_lat },
            longitude => { '>=', $min_lon, '<', $max_lon },
    };
    $q->{'current_timestamp - lastupdate'} = { '<', \"'$interval'::interval" }
        if $interval;

    my @problems = mySociety::Locale::in_gb_locale { $rs->search( $q, $attr )->all };
    return \@problems;
}

# Admin functions

sub timeline {
    my ( $rs ) = @_;

    my $prefetch = 
        FixMyStreet::App->model('DB')->schema->storage->sql_maker->quote_char ?
        [ qw/user/ ] :
        [];

    return $rs->search(
        {
            -or => {
                created  => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
                confirmed => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
                whensent  => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
            }
        },
        {
            prefetch => $prefetch,
        }
    );
}

sub summary_count {
    my ( $rs ) = @_;

    return $rs->search(
        undef,
        {
            group_by => ['state'],
            select   => [ 'state', { count => 'id' } ],
            as       => [qw/state state_count/]
        }
    );
}

sub unique_users {
    my ( $rs ) = @_;

    return $rs->search( {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
    }, {
        select => [ { count => { distinct => 'user_id' } } ],
        as     => [ 'count' ]
    } )->first->get_column('count');
}

sub categories_summary {
    my ( $rs ) = @_;

    my $fixed_case = "case when state IN ( '" . join( "', '", FixMyStreet::DB::Result::Problem->fixed_states() ) . "' ) then 1 else null end";
    my $categories = $rs->search( {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        whensent => { '<' => \"NOW() - INTERVAL '4 weeks'" },
    }, {
        select   => [ 'category', { count => 'id' }, { count => \$fixed_case } ],
        as       => [ 'category', 'c', 'fixed' ],
        group_by => [ 'category' ],
        result_class => 'DBIx::Class::ResultClass::HashRefInflator'
    } );
    my %categories = map { $_->{category} => { total => $_->{c}, fixed => $_->{fixed} } } $categories->all;
    return \%categories;
}

sub send_reports {
    # Set up site, language etc.
    my ($verbose, $nomail) = CronFns::options();
    my $base_url = mySociety::Config::get('BASE_URL');
    my $site = CronFns::site($base_url);

    my $unsent = FixMyStreet::App->model("DB::Problem")->search( {
        state => [ 'confirmed', 'fixed' ],
        whensent => undef,
        council => { '!=', undef },
    } );
    my (%notgot, %note);

    my $send_report = FixMyStreet::SendReport->new();
    my $senders = $send_report->get_senders;
    my %sending_skipped_by_method;

    while (my $row = $unsent->next) {

        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($row->cobrand)->new();

        # Cobranded and non-cobranded messages can share a database. In this case, the conf file 
        # should specify a vhost to send the reports for each cobrand, so that they don't get sent 
        # more than once if there are multiple vhosts running off the same database. The email_host
        # call checks if this is the host that sends mail for this cobrand.
        next unless $cobrand->email_host();
        $cobrand->set_lang_and_domain($row->lang, 1);
        if ( $row->is_from_abuser ) {
            $row->update( { state => 'hidden' } );
            next;
        }

        # Template variables for the email
        my $email_base_url = $cobrand->base_url_for_report($row);
        my %h = map { $_ => $row->$_ } qw/id title detail name category latitude longitude used_map/;
        map { $h{$_} = $row->user->$_ } qw/email phone/;
        $h{confirmed} = DateTime::Format::Pg->format_datetime( $row->confirmed->truncate (to => 'second' ) );

        $h{query} = $row->postcode;
        $h{url} = $email_base_url . $row->url;
        $h{phone_line} = $h{phone} ? _('Phone:') . " $h{phone}\n\n" : '';
        if ($row->photo) {
            $h{has_photo} = _("This web page also contains a photo of the problem, provided by the user.") . "\n\n";
            $h{image_url} = $email_base_url . '/photo/' . $row->id . '.full.jpeg';
        } else {
            $h{has_photo} = '';
            $h{image_url} = '';
        }
        $h{fuzzy} = $row->used_map ? _('To view a map of the precise location of this issue')
            : _('The user could not locate the problem on a map, but to see the area around the location they entered');
        $h{closest_address} = '';

        # If we are in the UK include eastings and northings, and nearest stuff
        $h{easting_northing} = '';
        if ( $cobrand->country eq 'GB' ) {

            ( $h{easting}, $h{northing} ) = Utils::convert_latlon_to_en( $h{latitude}, $h{longitude} );

            # email templates don't have conditionals so we need to farmat this here
            $h{easting_northing}                             #
              = "Easting: $h{easting}\n\n"                   #
              . "Northing: $h{northing}\n\n";

        }

        if ( $row->used_map ) {
            $h{closest_address} = $cobrand->find_closest( $h{latitude}, $h{longitude}, $row );
        }

        my %reporters = ();
        my ( $sender_count );
        if ($site eq 'emptyhomes') {

            my $council = $row->council;
            my $areas_info = mySociety::MaPit::call('areas', $council);
            my $sender = "FixMyStreet::SendReport::EmptyHomes";
            $reporters{ $sender } = $sender->new() unless $reporters{$sender};
            $reporters{ $sender }->add_council( $council, $areas_info->{$council} );

        } else {

            # XXX Needs locks!
            my @all_councils = split /,|\|/, $row->council;
            my ($councils, $missing) = $row->council =~ /^([\d,]+)(?:\|([\d,]+))?/;
            my @councils = split(/,/, $councils);
            my $areas_info = mySociety::MaPit::call('areas', \@all_councils);
            my @dear;

            foreach my $council (@councils) {
                my $name = $areas_info->{$council}->{name};

                my $sender = $cobrand->get_council_sender( $council, $areas_info->{$council} );
                $sender = "FixMyStreet::SendReport::$sender";

                if ( ! exists $senders->{ $sender } ) {
                    warn "No such sender [ $sender ] for council $name ( $council )";
                    next;
                }
                $reporters{ $sender } ||= $sender->new();

                if ( $reporters{ $sender }->should_skip( $row ) ) {
                    $sending_skipped_by_method{ $sender }++ if 
                        $reporters{ $sender }->skipped;
                } else {
                    push @dear, $name;
                    $reporters{ $sender }->add_council( $council, $areas_info->{$council} );
                }
            }

            if ($h{category} eq _('Other')) {
                $h{category_footer} = _('this type of local problem');
                $h{category_line} = '';
            } else {
                $h{category_footer} = "'" . $h{category} . "'";
                $h{category_line} = sprintf(_("Category: %s"), $h{category}) . "\n\n";
            }

            $h{councils_name} = join(_(' and '), @dear);
            if ($h{category} eq _('Other')) {
                $h{multiple} = @dear>1 ? "[ " . _("This email has been sent to both councils covering the location of the problem, as the user did not categorise it; please ignore it if you're not the correct council to deal with the issue, or let us know what category of problem this is so we can add it to our system.") . " ]\n\n"
                    : '';
            } else {
                $h{multiple} = @dear>1 ? "[ " . _("This email has been sent to several councils covering the location of the problem, as the category selected is provided for all of them; please ignore it if you're not the correct council to deal with the issue.") . " ]\n\n"
                    : '';
            }
            $h{missing} = ''; 
            if ($missing) {
                my $name = $areas_info->{$missing}->{name};
                $h{missing} = '[ '
                  . sprintf(_('We realise this problem might be the responsibility of %s; however, we don\'t currently have any contact details for them. If you know of an appropriate contact address, please do get in touch.'), $name)
                  . " ]\n\n";
            }

            $sender_count = scalar @dear;
        }

        unless ( keys %reporters ) {
            die 'Report not going anywhere for ID ' . $row->id . '!';
        }

        next unless $sender_count;

        if (mySociety::Config::get('STAGING_SITE')) {
            # on a staging server send emails to ourselves rather than the councils
            my @testing_councils = split( '\|', mySociety::Config::get('TESTING_COUNCILS') );
            unless ( grep { $row->council eq $_ } @testing_councils ) {
                %reporters = map { $_ => $reporters{$_} } grep { /FixMyStreet::SendReport::(Email|NI)/ } keys %reporters;
                unless (%reporters) {
                    %reporters = ( 'FixMyStreet::SendReport::Email' => FixMyStreet::SendReport::Email->new() );
                }
            }
        }

        # Multiply results together, so one success counts as a success.
        my $result = -1;

        for my $sender ( keys %reporters ) {
            $result *= $reporters{ $sender }->send( $row, \%h );
            if ( $reporters{ $sender }->unconfirmed_counts) {
                foreach my $e (keys %{ $reporters{ $sender }->unconfirmed_counts } ) {
                    foreach my $c (keys %{ $reporters{ $sender }->unconfirmed_counts->{$e} }) {
                        $notgot{$e}{$c} += $reporters{ $sender }->unconfirmed_counts->{$e}{$c};
                    }
                }
                %note = (
                    %note,
                    %{ $reporters{ $sender }->unconfirmed_notes }
                );
            }
        }

        if ($result == mySociety::EmailUtil::EMAIL_SUCCESS) {
            $row->update( {
                whensent => \'ms_current_timestamp()',
                lastupdate => \'ms_current_timestamp()',
            } );
        } else {
            my @errors;
            for my $sender ( keys %reporters ) {
                unless ( $reporters{ $sender }->success ) {
                    push @errors, $reporters{ $sender }->error;
                }
            }
            $row->update_send_failed( join( '|', @errors ) );
        }
    }

    if ($verbose) {
        print "Council email addresses that need checking:\n" if keys %notgot;
        foreach my $e (keys %notgot) {
            foreach my $c (keys %{$notgot{$e}}) {
                print "    " . $notgot{$e}{$c} . " problem, to $e category $c (" . $note{$e}{$c}. ")\n";
            }
        }
        if (keys %sending_skipped_by_method) {
            my $c = 0;
            print "\nProblem reports that send-reports did not attempt to send the following:\n";
            foreach my $send_method (sort keys %sending_skipped_by_method) {
                printf "    %-24s %4d\n", "$send_method:", $sending_skipped_by_method{$send_method};
                $c+=$sending_skipped_by_method{$send_method};
            }
            printf "    %-24s %4d\n", "Total:", $c;
        }
    }
}

1;
