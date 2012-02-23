package FixMyStreet::DB::ResultSet::Problem;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

my $site_restriction;
my $site_key;

sub set_restriction {
    my ( $rs, $sql, $key, $restriction ) = @_;
    $site_key = $key;
    $site_restriction = $restriction;
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
    my $key = "recent:$site_key";
    my $result = Memcached::get($key);
    if ( $result ) {
        # Need to reattach schema so that confirmed column gets reinflated.
        $result->[0]->result_source->schema( $rs->result_source->schema ) if $result->[0];
    } else {
        $result = [ $rs->search( {
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ]
        }, {
            columns => [ 'id', 'title', 'confirmed' ],
            order_by => { -desc => 'confirmed' },
            rows => 5,
        } )->all ];
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

sub recent_photos {
    my ( $rs, $num, $lat, $lon, $dist ) = @_;
    my $probs;
    my $query = {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        photo => { '!=', undef },
    };
    my $attrs = {
        columns => [ 'id', 'title' ],
        order_by => { -desc => 'confirmed' },
        rows => $num,
    };
    if (defined $lat) {
        my $dist2 = $dist; # Create a copy of the variable to stop it being stringified into a locale in the next line!
        my $key = "recent_photos:$site_key:$num:$lat:$lon:$dist2";
        $probs = Memcached::get($key);
        unless ($probs) {
            $attrs->{bind} = [ $lat, $lon, $dist ];
            $attrs->{join} = 'nearby';
            $probs = [ mySociety::Locale::in_gb_locale {
                $rs->search( $query, $attrs )->all;
            } ];
            Memcached::set($key, $probs, 3600);
        }
    } else {
        my $key = "recent_photos:$site_key:$num";
        $probs = Memcached::get($key);
        unless ($probs) {
            $probs = [ $rs->search( $query, $attrs )->all ];
            Memcached::set($key, $probs, 3600);
        }
    }
    return $probs;
}

# Problems around a location

sub around_map {
    my ( $rs, $min_lat, $max_lat, $min_lon, $max_lon, $interval, $limit ) = @_;
    my $attr = {
        order_by => { -desc => 'created' },
        columns => [
            'id', 'title' ,'latitude', 'longitude', 'state', 'confirmed'
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


use Digest::MD5;
use Encode;
use Error qw(:try);
use JSON;
use LWP::UserAgent;
use LWP::Simple;
use CGI; # Trying awkward kludge
use CronFns;

use FixMyStreet::App;

use EastHantsWSDL;
use Utils;
use mySociety::Config;
use mySociety::EmailUtil;
use mySociety::MaPit;
use mySociety::Web qw(ent);

use Open311;

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

    my $send_email = 0;
    my $send_web = 0;

    # Template variables for the email
    my $email_base_url = $cobrand->base_url_for_emails($row->cobrand_data);
    my %h = map { $_ => $row->$_ } qw/id title detail name category latitude longitude used_map/;
    map { $h{$_} = $row->user->$_ } qw/email phone/;
    $h{confirmed} = DateTime::Format::Pg->format_datetime( $row->confirmed->truncate (to => 'second' ) );

    $h{query} = $row->postcode;
    $h{url} = $email_base_url . '/report/' . $row->id;
    $h{phone_line} = $h{phone} ? _('Phone:') . " $h{phone}\n\n" : '';
    if ($row->photo) {
        $h{has_photo} = _("This web page also contains a photo of the problem, provided by the user.") . "\n\n";
        $h{image_url} = $email_base_url . '/photo?id=' . $row->id;
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

    my (@to, @recips, $template, $areas_info, @open311_councils);
    if ($site eq 'emptyhomes') {

        my $council = $row->council;
        $areas_info = mySociety::MaPit::call('areas', $council);
        my $name = $areas_info->{$council}->{name};
        my $contact = FixMyStreet::App->model("DB::Contact")->find( {
            deleted => 0,
            area_id => $council,
            category => 'Empty property',
        } );
        my ($council_email, $confirmed, $note) = ( $contact->email, $contact->confirmed, $contact->note );
        unless ($confirmed) {
            $note = 'Council ' . $council . ' deleted' unless $note;
            $council_email = 'N/A' unless $council_email;
            $notgot{$council_email}{$row->category}++;
            $note{$council_email}{$row->category} = $note;
            next;
        }

        push @to, [ $council_email, $name ];
        @recips = ($council_email);
        $send_email = 1;
        $template = Utils::read_file("$FindBin::Bin/../templates/email/emptyhomes/" . $row->lang . "/submit.txt");

    } else {

        # XXX Needs locks!
        my @all_councils = split /,|\|/, $row->council;
        my ($councils, $missing) = $row->council =~ /^([\d,]+)(?:\|([\d,]+))?/;
        my @councils = split(/,/, $councils);
        $areas_info = mySociety::MaPit::call('areas', \@all_councils);
        my (@dear, %recips);
        my $all_confirmed = 1;
        foreach my $council (@councils) {
            my $name = $areas_info->{$council}->{name};
            push @dear, $name;
            if ($council == 2330) { # E. Hants have a web service
                $send_web = 'easthants';
                $h{category} = 'Customer Services' if $h{category} eq 'Other';
            } elsif ($areas_info->{$council}->{type} eq 'LBO') { # London
                $send_web = 'london';
            } elsif ( my $endpoint = FixMyStreet::App->model("DB::Open311conf")->search( { area_id => $council, endpoint => { '!=', '' } } )->first ) {
                push @open311_councils, $endpoint;
                $send_web = 'open311';
            } else {
                my $contact = FixMyStreet::App->model("DB::Contact")->find( {
                    deleted => 0,
                    area_id => $council,
                    category => $row->category
                } );
                my ($council_email, $confirmed, $note) = ( $contact->email, $contact->confirmed, $contact->note );
                $council_email = essex_contact($row->latitude, $row->longitude) if $council == 2225;
                $council_email = oxfordshire_contact($row->latitude, $row->longitude) if $council == 2237 && $council_email eq 'SPECIAL';
                unless ($confirmed) {
                    $all_confirmed = 0;
                    $note = 'Council ' . $row->council . ' deleted'
                        unless $note;
                    $council_email = 'N/A' unless $council_email;
                    $notgot{$council_email}{$row->category}++;
                    $note{$council_email}{$row->category} = $note;
                }
                push @to, [ $council_email, $name ];
                $recips{$council_email} = 1;
                $send_email = 1;
            }
        }
        @recips = keys %recips;
        next unless $all_confirmed;

        $template = 'submit.txt';
        $template = 'submit-brent.txt' if $row->council eq 2488 || $row->council eq 2237;
        my $template_path = FixMyStreet->path_to( "templates", "email", $cobrand->moniker, $template )->stringify;
        $template_path = FixMyStreet->path_to( "templates", "email", "default", $template )->stringify
            unless -e $template_path;
        $template = Utils::read_file( $template_path );

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

    }

    unless ($send_email || $send_web) {
        die 'Report not going anywhere for ID ' . $row->id . '!';
    }

    if (mySociety::Config::get('STAGING_SITE')) {
        # on a staging server send emails to ourselves rather than the councils
        @recips = ( mySociety::Config::get('CONTACT_EMAIL') );
        $send_web = 0;
        $send_email = 1;
    } elsif ($site eq 'emptyhomes') {
        my $council = $row->council;
        my $country = $areas_info->{$council}->{country};
        if ($country eq 'W') {
            push @recips, 'shelter@' . mySociety::Config::get('EMAIL_DOMAIN');
        } else {
            push @recips, 'eha@' . mySociety::Config::get('EMAIL_DOMAIN');
        }
    }

    # Special case for this parish council
    # if ($address && $address =~ /Sprowston/ && $row->council == 2233 && $row->category eq 'Street lighting') {
    #     $h{councils_name} = 'Sprowston Parish Council';
    #     my $e = 'parishclerk' . '@' . 'sprowston-pc.gov.uk';
    #     @to = ( [ $e, $h{councils_name} ] );
    #     @recips = ($e);
    # }

    # Multiply results together, so one success counts as a success.
    my $result = -1;

    if ($send_email) {
        $result *= FixMyStreet::App->send_email_cron(
            {
                _template_ => $template,
                _parameters_ => \%h,
                To => \@to,
                From => [ $row->user->email, $row->name ],
            },
            mySociety::Config::get('CONTACT_EMAIL'),
            \@recips,
            $nomail
        );
    }

    if ($send_web eq 'easthants') {
        $h{message} = construct_easthants_message(%h);
        if (!$nomail) {
            $result *= post_easthants_message(%h);
        }
    } elsif ($send_web eq 'london') {
        $h{message} = construct_london_message(%h);
        if (!$nomail) {
            $result *= post_london_report( $row, %h );
        }
    } elsif ($send_web eq 'open311') {
        foreach my $conf ( @open311_councils ) {
            print 'posting to end point for ' . $conf->area_id . "\n" if $verbose;

            my $contact = FixMyStreet::App->model("DB::Contact")->find( {
                deleted => 0,
                area_id => $conf->area_id,
                category => $row->category
            } );

            my $open311 = Open311->new(
                jurisdiction => $conf->jurisdiction,
                endpoint     => $conf->endpoint,
                api_key      => $conf->api_key,
            );

            # non standard west berks end points
            if ( $row->council =~ /2619/ ) {
                $open311->endpoints( { services => 'Services', requests => 'Requests' } );
            }

            # required to get round issues with CRM constraints
            if ( $row->council =~ /2218/ ) {
                $row->user->name( $row->user->id . ' ' . $row->user->name );
            }

            my $resp = $open311->send_service_request( $row, \%h, $contact->email );

            # make sure we don't save user changes from above
            if ( $row->council =~ /2218/ ) {
                $row->discard_changes();
            }

            if ( $resp ) {
                $row->external_id( $resp );
                $result *= 0;
            } else {
                $result *= 1;
                # temporary fix to resolve some issues with west berks
                if ( $row->council =~ /2619/ ) {
                    $result *= 0;
                }
            }
        }
    }

    if ($result == mySociety::EmailUtil::EMAIL_SUCCESS) {
        $row->update( {
            whensent => \'ms_current_timestamp()',
            lastupdate => \'ms_current_timestamp()',
        } );
    }
}

if ($verbose) {
    print "Council email addresses that need checking:\n" if keys %notgot;
    foreach my $e (keys %notgot) {
        foreach my $c (keys %{$notgot{$e}}) {
            print $notgot{$e}{$c} . " problem, to $e category $c (" . $note{$e}{$c}. ")\n";
        }
    }
}
}

sub _get_district_for_contact {
    my ( $lat, $lon ) = @_;
    my $district =
      mySociety::MaPit::call( 'point', "4326/$lon,$lat", type => 'DIS' );
    ($district) = keys %$district;
    return $district;
}

# Essex has different contact addresses depending upon the district
# Might be easier if we start storing in the db all areas covered by a point
# Will do for now :)
sub essex_contact {
    my $district = _get_district_for_contact(@_);
    my $email;
    $email = 'eastarea' if $district == 2315 || $district == 2312;
    $email = 'midarea' if $district == 2317 || $district == 2314 || $district == 2316;
    $email = 'southarea' if $district == 2319 || $district == 2320 || $district == 2310;
    $email = 'westarea' if $district == 2309 || $district == 2311 || $district == 2318 || $district == 2313;
    die "Returned district $district which is not in Essex!" unless $email;
    return "highways.$email\@essexcc.gov.uk";
}

# Oxfordshire has different contact addresses depending upon the district
sub oxfordshire_contact {
    my $district = _get_district_for_contact(@_);
    my $email;
    $email = 'northernarea' if $district == 2419 || $district == 2420 || $district == 2421;
    $email = 'southernarea' if $district == 2417 || $district == 2418;
    die "Returned district $district which is not in Oxfordshire!" unless $email;
    return "$email\@oxfordshire.gov.uk";
}

# East Hampshire

sub construct_easthants_message {
    my %h = @_;
    my $message = '';
    $message .= "[ This report was also sent to the district council covering the location of the problem, as the user did not categorise it; please ignore if you're not the correct council to deal with the issue. ]\n\n"
        if $h{multiple};
    $message .= <<EOF;
Subject: $h{title}

Details: $h{detail}

$h{fuzzy}, or to provide an update on the problem, please visit the following link:

$h{url}

$h{closest_address}
EOF
    return $message;
}

my $eh_service;
sub post_easthants_message {
    my %h = @_;
    my $return = 1;
    $eh_service ||= EastHantsWSDL->on_fault(sub { my($soap, $res) = @_; die ref $res ? $res->faultstring : $soap->transport->status, "\n"; });
    try {
        # ServiceName, RemoteCreatedBy, Salutation, FirstName, Name, Email, Telephone, HouseNoName, Street, Town, County, Country, Postcode, Comments, FurtherInfo, ImageURL
        my $message = ent(encode_utf8($h{message}));
        my $name = ent(encode_utf8($h{name}));
        my $result = $eh_service->INPUTFEEDBACK(
            $h{category}, 'FixMyStreet', '', '', $name, $h{email}, $h{phone},
            '', '', '', '', '', '', $message, 'Yes', $h{image_url}
        );
        $return = 0 if $result eq 'Report received';
    } otherwise {
        my $e = shift;
        print "Caught an error: $e\n";
    };
    return $return;
}

# London

sub construct_london_message {
    my %h = @_;
    return <<EOF,
A user of FixMyStreet has submitted the following report of a local
problem that they believe might require your attention.

Subject: $h{title}

Details: $h{detail}

$h{fuzzy}, or to provide an update on the problem, please visit the
following link:

$h{url}

$h{closest_address}
Yours,
The FixMyStreet team
EOF
}

sub post_london_report {
    my ( $problem, %h ) = @_;
    my $phone = $h{phone};
    my $mobile = '';
    if ($phone && $phone =~ /^\s*07/) {
        $mobile = $phone;
        $phone = '';
    }
    my ($first, $last) = $h{name} =~ /^(\S*)(?: (.*))?$/;
    my %params = (
        Key => mySociety::Config::get('LONDON_REPORTIT_KEY'),
        Signature => Digest::MD5::md5_hex( $h{confirmed} . mySociety::Config::get('LONDON_REPORTIT_SECRET') ),
        Type => Utils::london_categories()->{$h{category}},
        RequestDate => $h{confirmed},
        RequestMethod => 'Web',
        ExternalId => $h{url},
        'Customer.Title' => '',
        'Customer.FirstName' => $first,
        'Customer.Surname' => $last,
        'Customer.Email' => $h{email},
        'Customer.Phone' => $phone,
        'Customer.Mobile' => $mobile,
        'ProblemDescription' => $h{message},
    );
    if ($h{used_map}) {
        $params{'Location.Latitude'} = $h{latitude};
        $params{'Location.Longitude'} = $h{longitude};
    } elsif (mySociety::PostcodeUtil::is_valid_postcode($h{query})) {
        # Didn't use map, and entered postcode, so use that.
        $params{'Location.Postcode'} = $h{query};
    } else {
        # Otherwise, lat/lon is all we have, even if it's wrong.
        $params{'Location.Latitude'} = $h{latitude};
        $params{'Location.Longitude'} = $h{longitude};
    }
    if ($h{has_photo}) {
        $params{'Document1.Name'} = 'Photograph';
        $params{'Document1.MimeType'} = 'image/jpeg';
        $params{'Document1.URL'} = $h{image_url};
        $params{'Document1.URLPublic'} = 'true';
    }
    my $browser = LWP::UserAgent->new;
    my $response = $browser->post( mySociety::Config::get('LONDON_REPORTIT_URL'), \%params );
    my $out = $response->content;
    if ($response->code ne 200) {
        print "Failed to post $h{id} to London API, response was " . $response->code . " $out\n";
        return 1;
    }
    my ($id) = $out =~ /<caseid>(.*?)<\/caseid>/;
    my ($org) = $out =~ /<organisation>(.*?)<\/organisation>/;
    my ($team) = $out =~ /<team>(.*?)<\/team>/;

    $org = london_lookup($org);
    $problem->external_id( $id );
    $problem->external_body( $org );
    $problem->external_team( $team );
    return 0;
}

# Nearest things

sub london_lookup {
    my $org = shift || '';
    my $str = "Unknown ($org)";
    open(FP, "$FindBin::Bin/../data/dft.csv");
    while (<FP>) {
        /^(.*?),(.*)/;
        if ($org eq $1) {
            $str = $2;
            last;
        }
    }
    close FP;
    return $str;
}

1;
