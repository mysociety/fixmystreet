package FixMyStreet::DB::ResultSet::Problem;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

use FixMyStreet::SendReport::Email;

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

    my %reporters = ();
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
            my $sender = $cobrand->get_council_sender( $council, $areas_info->{$council} );
            $sender = "FixMyStreet::SendReport::$sender";
            $reporters{ $sender } = $sender->new() unless $reporters{$sender};
            $reporters{ $sender }->add_council( $council, $name );
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

    unless ($send_email || $send_web || keys %reporters ) {
        die 'Report not going anywhere for ID ' . $row->id . '!';
    }

    if (mySociety::Config::get('STAGING_SITE')) {
        # on a staging server send emails to ourselves rather than the councils
        @recips = ( mySociety::Config::get('CONTACT_EMAIL') );
        $send_web = 0;
        $send_email = 1;
        %reporters = (
            'FixMyStreet::SendReport::Email' => $reporters{ 'FixMyStreet::SendReport::Email' }
        );
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

    for my $sender ( keys %reporters ) {
        $result *= $reporters{ $sender }->send(
            $row, \%h, \@to, $template, \@recips, $nomail
        );
    }
    #if ($send_email) {
        #$result *= FixMyStreet::SendReport::Email::send(
        #);
    #}

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

1;
