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

sub site_title { return 'Collideoscope'; }

sub enter_postcode_text {
    my ( $self ) = @_;
    return _('Street, area, or landmark');
}

sub severity_categories {
    return [
        {
            value => 10,
            name => 'Potential Minor',
            description => 'could have involved scrapes and bruises',
        },
        {
            value => 30,
            name => 'Minor',
            description => 'incident involved scrapes and bruises',
        },
        {
            value => 50,
            name => 'Potential Serious',
            description => 'could have involved serious injury or hospitalisation',
        },
        {
            value => 75,
            name => 'Serious',
            description => 'incident involved serious injury or hospitalisation',
        },
        {
            value => 90,
            name => 'Fatal',
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
    return '7 days';
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;

    return $p->category;
}

sub category_options {
    return ();
}

sub process_extras {
    my ($self, $ctx, undef, $extra) = @_;

    my @fields = (
        {
            name => 'severity',
            validator => sub {
                my $sev = shift;
                if ($sev > 0 and $sev <= 100) {
                    return $sev+0;
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
                        "bike-car" => 1,
                        "bike-other" => 1,
                        "pedestrian-bike" => 1,
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
}

# this is required to use new style templates
sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub base_url {
    my $self = shift;
    my $base_url = mySociety::Config::get('BASE_URL');
    my $u = $self->moniker;
    if ( $base_url !~ /$u/ ) {
        $base_url =~ s{http://(?!www\.)}{http://$u.}g;
        $base_url =~ s{http://www\.}{http://$u.}g;
    }
    return $base_url;
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
    my ($new, $miss) = $self->recent_new( $recency );

    my $stats = {
        updates => $updates,
        new     => $new,
        misses => $miss,
        accidents => $new - $miss,
        recency => $recency,
    };

    return $stats;
}

=head2 recent_new

Specialised from RS::Problem

=cut

sub recent_new {
    my ( $self, $interval ) = @_;
    my $rs = $self->{c}->model('DB::Problem');

    my $site_key = $self->site_key;

    (my $key = $interval) =~ s/\s+//g;

    my $new_key = "recent_new:$site_key:$key";
    my $miss_key = "recent_new_miss$site_key:$key";

    my ($new, $miss) = (Memcached::get($new_key), Memcached::get($miss_key));

    if (! ($new && $miss)) {
        $rs = $rs->search( {
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
            confirmed => { '>', \"current_timestamp-'$interval'::interval" },
        });
        $new = $rs->count;
        Memcached::set($new_key, $new, 3600);

        $miss = $rs->search({ category => { like => '%miss' } })->count;
        Memcached::set($miss_key, $miss, 3600);
    }

    return ($new, $miss);
}

sub extra_stats_cols { ('category') }

sub stats_open_problem_type {
    my ($self, $problem) = @_;

    my $age = $self->SUPER::stats_open_problem_type($problem);
    my $category = $problem->{category};

    my $metacategory = $category =~ /miss$/ ? 'miss' : 'accident';

    return "${age}_${metacategory}";
}

1;
