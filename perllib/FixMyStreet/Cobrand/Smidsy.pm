package FixMyStreet::Cobrand::Smidsy;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

use FixMyStreet;
use DateTime;
use DateTime::Format::Strptime;
use Utils;
use URI;
use URI::QueryParam;
use JSON;
use List::Util 'first';

# http://mapit.mysociety.org/area/2247.html
use constant area_id => 2247;

use constant extra_global_fields => 1;
use constant uses_global_categories => 1;

use constant language_domain => 'FixMyStreet-Smidsy';

use constant severity_minor_threshold => 40;
use constant severity_major_threshold => 70;

use constant STATS19_IMPORT_USER => 'hakim+smidsy@mysociety.org';
use constant LATEST_STATS19_UPDATE => 2013; # TODO, constant for now

sub site_title { return 'Collideoscope'; }

sub enter_postcode_text {
    my ( $self ) = @_;
    return _('Street, area, or landmark');
}

sub severity_categories {
    return [
        {
            value => 10,
            name => 'Near Miss',
            code => 'miss',
            description => 'could have involved scrapes and bruises',
        },
        {
            value => 30,
            name => 'Minor',
            code => 'slight',
            description => 'incident involved scrapes and bruises',
        },
        {
            value => 60,
            name => 'Serious',
            code => 'serious',
            description => 'incident involved serious injury or hospitalisation',
        },
        {
            value => 100,
            name => 'Fatal',
            code => 'fatal',
            description => 'incident involved the death of one or more road users',
        },
    ];
}

sub severity_categories_json {
    my $self = shift;
    return JSON->new->encode( $self->severity_categories );
}

sub get_severity {
    my ($self, $severity) = @_;
    return first { $severity >= $_->{value} }
        reverse @{ $self->severity_categories };
}

sub area_types          {
    my $self = shift;
    my $area_types = $self->next::method;
    [
        @$area_types,
        'GLA', # Greater London Authority
    ];
}

sub on_map_default_max_pin_age {
    return '1 month'; # use the checkbox to view the Stats19 data
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;

    return $p->category;
}

sub path_to_pin_icons {
    return '/cobrands/smidsy/images/';
}

sub category_options {
    return ();
}

sub process_extras {
    my ($self, $ctx, undef, $extra) = @_;

    return if ref $extra eq 'ARRAY'; # this is an update. Oh for strong typing. TODO refactor

    my @fields = (
        {
            name => 'severity',
            validator => sub {
                my $sev = shift;
                die "Severity not supplied\n" unless defined $sev;
                if ($sev > 0 and $sev <= 100) {
                    return $sev;
                }
                die "Severity must be between 1 and 100\n";
            },
        },
        {
            name => 'incident_date',
            validator => sub {
                my $data = shift;
                my $date;

                if ($data eq 'today') {
                    $date = DateTime->today;
                }
                else {
                    $date = DateTime::Format::Strptime->new(
                        pattern => '%d/%m/%Y'
                    )->parse_datetime($data);
                }
                if (! $date) {
                    die "Please input a valid date in format dd/mm/yyyy\n";
                }
                return $date->date; # yyyy-mm-dd
            },
        },
        {
            name => 'incident_time',
            validator => sub {
                my $data = shift or return;
                die "Please input a valid time in format hh:mm\n"
                    unless $data =~ /^\d{1,2}:\d{2}$/;
                return $data;
            },
        },
        {
            name => 'participants',
            validator => sub {
                my $data = shift;
                die "Invalid option!\n"
                    unless {
                        "bicycle" => 1,
                        "car" => 1,
                        "hgv" => 1,
                        "other" => 1,
                        "pedestrian" => 1,
                        "motorcycle" => 1,
                        "horse" => 1, # though no option on form (as yet)
                        "generic" => 1,
                    }->{ $data };
                return $data;
            },
        },
        {
            name => 'emergency_services',
            validator => sub {
                my $data = shift;
                die "Invalid option!\n"
                    unless {
                        "yes" => 1,
                        "no" => 1,
                        "unsure" => 1,
                    }->{ $data };
                return $data;
            },
        },
        {
            name => 'road_type',
            validator => sub {
                my $data = shift;
                die "Invalid option!\n"
                    unless {
                        "road" => 1,
                        "lane-onroad" => 1,
                        "lane-separate" => 1,
                        "pavement" => 1,
                    }->{ $data };
                return $data;
            },
        },
        {
            name => 'registration',
            validator => sub {
                # ok not to pass one, just accept anything for now
                return shift;
            },
        },
        {
            name => 'injury_detail',
            validator => sub { shift } # accept as is
        },
        {
            name => 'media_url',
            validator => sub {
                my $data = shift
                    or return '';
                # die "Please enter a valid URL\n" if $data =~ ... # TODO
                $data = 'http://' . $data
                    unless $data =~ m{://};
                return $data;
            },
        },
    );


    for my $field ( @fields ) {
        my $field_name = ref $field ? $field->{name} : $field;
        my $description;
        my $value = $ctx->request->param( $field_name );

        if (ref $field) {
            $description = $field->{value} || uc $field_name;

            eval {
                $value = $field->{validator}->($value);
            };
            if ($@) {
                $ctx->stash->{field_errors}->{ $field_name } = $@;
            }

        }
        else {
            if ( !$value ) {
                $ctx->stash->{field_errors}->{ $field_name } = _('This information is required');
            }
            $description = uc $field_name;
        }

        $extra->{$field_name} = $value || '';
    }

    $extra->{incident_date_as_submitted} = $ctx->request->param('incident_date') if $extra->{incident_date};
}

sub munge_report {
    my ($self, $c, $report) = @_;

    my $severity = $report->extra->{severity} or die;
    my $severity_code = $self->get_severity($severity)->{code};

    my ($type, $type_description) = $report->extra->{severity} > 10 ?
        ('accident', ucfirst "$severity_code incident") :
        ('miss', 'Near miss');

    my $participant = $report->extra->{participants};

    my $participants = do {
        if ($participant eq 'bicycle') {
            '2 bicycles'
        }
        elsif ($participant eq 'generic') {
            'just one bicycle';
        }
        else {
            $participant = 'vehicle' unless $participant eq 'pedestrian';

            my $participant_description =
            {
                pedestrian => 'a pedestrian',
                car => 'a car',
                hgv => 'an HGV',
                motorcycle => 'a motorcycle',
            }->{$participant} || 'a vehicle';
            "a bicycle and $participant_description";
        }
    };

    my $category = "$participant-$severity_code";
    my $title = "$type_description involving $participants";

    if (my $injury_detail = $report->extra->{injury_detail}) {
        $report->detail(
            $report->detail .
                "\n\nDetails about injuries: $injury_detail\n"
        );
    }

    $report->category($category);
    $report->title($title);
}

# this is required to use new style templates
sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub get_embed_code {
    my ($self, $problem) = @_;

    my $media_url = $problem->extra->{media_url}
        or return;

    my $uri = URI->new( $media_url );

    if ($uri->host =~ /youtube.com$/) {
        my $v = $uri->query_param('v') or return;
        return qq{<iframe width="320" height="195" src="//www.youtube.com/embed/$v"
            frameborder="0" allowfullscreen></iframe>};
    }

    if ($uri->host =~ /vimeo.com$/) {
        my ($v) = $uri->path =~ m{^/(\w+)};
        return qq{<iframe src="//player.vimeo.com/video/$v" width="320" height="195"
            frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>};
    }

    return;
}

sub prettify_incident_dt {
    my ($self, $problem) = @_;

    my ($date, $time) = eval {
        my $extra = $problem->extra;

        ($extra->{incident_date}, $extra->{incident_time});
    } or return 'unknown';

    my $dt = eval {
        my $dt = DateTime::Format::Strptime->new(
            pattern => '%F', # yyyy-mm-dd
        )->parse_datetime($date);
    } or return 'unknown';

    if ($time && $time =~ /^(\d+):(\d+)$/) {
        $dt->add( hours => $1, minutes => $2 );
        return Utils::prettify_dt( $dt );
    }
    else {
        return Utils::prettify_dt( $dt, 'date' );
    };
}

=head2 front_stats_data

Return a data structure containing the front stats information that a template
can then format.

=cut

sub front_stats_data {
    my ( $self ) = @_;

    my $recency         = '1 week';
    $recency = '12 months'; # override

    my $updates = $self->problems->number_comments();
    my $stats = $self->recent_new( $recency );

    my ($new, $miss) = ($stats->{new}, $stats->{miss});

    return {
        updates => $updates,
        new     => $new,
        misses => $miss,
        accidents => $new - $miss,
        stats19 => $stats->{stats19},,
        recency => $recency,
    };
}

=head2 recent_new

Specialised from RS::Problem's C<recent_new>

=cut

sub recent_new {
    my ( $self, $interval ) = @_;
    my $rs = $self->{c}->model('DB::Problem');

    my $site_key = $self->site_key;

    (my $key = $interval) =~ s/\s+//g;

    my %keys = (
        'new'     => "recent_new:$site_key:$key",
        'miss'    => "recent_new_miss:$site_key:$key",
        'stats19' => sprintf ("latest_stats19:$site_key:%d", LATEST_STATS19_UPDATE),
    );

    # unfortunately, we can't just do 
    #     'user.email' => { '!=', STATS19_IMPORT_USER }, }, { join => 'user', });
    # for the following 2 queries
    # until https://github.com/mysociety/fixmystreet/issues/1084 is fixed
    my $user_id = do {
        my $user = $self->{c}->model('DB::User')->find({ email => STATS19_IMPORT_USER });
        $user ? $user->id : undef;
    };

    my $recent_rs = $rs->search( {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        created => { '>', \"current_timestamp-'$interval'::interval" },
        $user_id ? ( user_id => { '!=', $user_id } ) : (),
    });

    my $stats_rs = $rs->search( {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        created => { '>=', sprintf ('%d-01-01', LATEST_STATS19_UPDATE ),
                        '<', sprintf ('%d-01-01', LATEST_STATS19_UPDATE+1 ) },
        $user_id ? ( user_id => $user_id ) : (),
    });

    my %values = map { 
        my $mkey = $keys{$_};
        my $value = Memcached::get($mkey) || do {
            my $value = 
                $_ eq 'new'  ? $recent_rs->count :
                $_ eq 'miss' ? $recent_rs->search({ category => { like => '%miss' } })->count :
                $_ eq 'stats19' ? $stats_rs->count : die 'FATAL error';

            Memcached::set($mkey, $value, 3600);
            $value
        };
        ( $_ => $value );
    } keys %keys;

    return \%values;
}

sub extra_stats_cols { ('category') }

sub stats_open_problem_type {
    my ($self, $problem) = @_;

    my $age = $self->SUPER::stats_open_problem_type($problem);
    my $category = $problem->{category};

    my $metacategory = $category =~ /miss$/ ? 'miss' : 'accident';

    return "${age}_${metacategory}";
}

sub subject_line_for_contact_email {
    my ($self, $subject) = @_;
    return 'Collideoscope message: ' . $subject;
}

=head2 _fallback_body_sender

Override _fallback_body_sender from the UK cobrand so that we don't do things
differently for bodies in London or Northern Ireland.

Note: Northern Ireland reports will actually be sent to 1 of 2 (or maybe 4?)
highways agencies, but we've assigned the appropriate email addresses to each
NI council body in the database, so we don't need to use the special NI
sending method to achieve this.

=cut
sub _fallback_body_sender {
    my ( $self, $body, $category ) = @_;

    return { method => 'Email' };
};

sub is_stats19 {
    my ($self, $problem) = @_;
    return $problem->name eq 'Stats19 import';
}

sub report_meta_line {
    my ($self, $problem, $date_time) = @_;

    my $occurred = sprintf '(incident occurred: %s)',
        $self->prettify_incident_dt( $problem );

    if ($self->is_stats19($problem)) {
        return sprintf 'Reported to the police and recorded by Stats19 %s',
            $occurred;
    }
    elsif ($problem->anonymous) {
        return sprintf 'Reported anonymously at %s %s',
            $date_time, $occurred;
    }
    else {
        return sprintf 'Reported by %s at %s %s',
            $problem->name, $date_time, $occurred;
    }
}

sub send_questionnaires {
    return 0;
}

=head2 display_location_extra_params

Return additional Problem query parameters for use in showing problems on
the /around page during the
FixMyStreet::App::Controller::Around::display_location action.

Specialised to return a flag to filter problems by the external_body field if
the user would like to see Stats19 problems.

=cut
sub display_location_extra_params {
    my ($self, $c) = @_;
    if ($c->get_param('show_stats19')) {
        # Stash this for later
        $c->stash->{show_stats19} = $c->get_param('show_stats19');
        return {
            external_body => 'stats19',
            # TODO - this is needed to override the default interval that's
            # provided (1 Month). I'm not sure if there's an easier way to do
            # it and actually unset this value perhaps?
            'current_timestamp - lastupdate' => { '<', \"'100 years'::interval" }
        }
    } else {
        return {
            external_body => {'!=' => 'stats19'},
        }
    }
}

1;
