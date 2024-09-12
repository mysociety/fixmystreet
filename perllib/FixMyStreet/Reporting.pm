package FixMyStreet::Reporting;

use DateTime;
use Moo;
use Path::Tiny;
use Text::CSV;
use Types::Standard qw(ArrayRef CodeRef Enum HashRef InstanceOf Int Maybe Str);
use FixMyStreet::DB;

# What are we reporting on

has dbi => ( is => 'ro' );
has type => ( is => 'ro', isa => Enum['problems','updates'] );
has on_problems => ( is => 'lazy', default => sub { $_[0]->type eq 'problems' } );
has on_updates => ( is => 'lazy', default => sub { $_[0]->type eq 'updates' } );

# Filters to restrict the reporting to

has body => ( is => 'ro', isa => Maybe[InstanceOf['FixMyStreet::DB::Result::Body']] );
has wards => ( is => 'ro', isa => ArrayRef[Int], default => sub { [] } );
has category => ( is => 'ro', isa => ArrayRef[Str], default => sub { [] } );
has state => ( is => 'ro', isa => Maybe[Str] );
has start_date => ( is => 'rwp',
    isa => Str,
    default => sub {
        my $days30 = DateTime->now(time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone)->subtract(days => 30);
        $days30->truncate( to => 'day' );
        $days30->strftime('%Y-%m-%d');
    }
);
has end_date => ( is => 'ro', isa => Maybe[Str] );
has role_id => ( is => 'ro', isa => Maybe[Int] );

# Things needed for cobrand specific extra data or checks

has cobrand => ( is => 'ro', default => sub { FixMyStreet::DB->schema->cobrand } ); # Which cobrand is asking, to get the right data / hooks / base URL
has user => ( is => 'ro', isa => Maybe[InstanceOf['FixMyStreet::DB::Result::User']] );

# Things created in the process, that can be manually overridden

has objects_rs => ( is => 'rwp' ); # ResultSet of rows

sub objects_attrs {
    my ($self, $attrs) = @_;
    my $rs = $self->objects_rs->search(undef, $attrs);
    $self->_set_objects_rs($rs);
    return $rs;
}

# CSV header strings and column keys (looked up in the row's as_hashref, plus
# the following: user_name_display, acknowledged, fixed, closed, wards,
# local_coords_x, local_coords_y, url, subcategory, cobrand, reported_as)
has csv_headers => ( is => 'rwp', isa => ArrayRef[Str], default => sub { [] } );
has csv_columns => ( is => 'rwp', isa => ArrayRef[Str], default => sub { [] } );

sub modify_csv_header {
    my ($self, %mapping) = @_;
    $self->_set_csv_headers([
        map { $mapping{$_} || $_ } @{ $self->csv_headers },
    ]);
}

sub splice_csv_column {
    my ($self, $before, $column, $header) = @_;

    for (my $i = 0; $i < @{$self->csv_columns}; $i++) {
        my $col = $self->csv_columns->[$i];
        if ($col eq $before) {
            splice @{$self->csv_columns}, $i, 0, $column;
            splice @{$self->csv_headers}, $i, 0, $header;
            last;
        }
    }
}

sub add_csv_columns {
    my $self = shift;
    for (my $i = 0; $i < @_; $i += 2) {
        my $column = $_[$i];
        my $header = $_[$i+1];
        push @{$self->csv_columns}, $column;
        push @{$self->csv_headers}, $header;
    }
}

# A function that is passed the report and returns a hashref of extra data to
# include that can be used by 'columns'
has csv_extra_data => ( is => 'rw', isa => CodeRef );

has filename => ( is => 'rw', isa => Str, lazy => 1, default => sub {
    my $self = shift;
    my %where = (
        state => $self->state,
        ward => join(',', @{$self->wards}),
        start_date => $self->start_date,
        end_date => $self->end_date,
    );
    $where{category} = @{$self->category} < 3 ? join(',', @{$self->category}) : 'multiple-categories';
    $where{body} = $self->body->id if $self->body;
    $where{role} = $self->role_id if $self->role_id;
    my $host = URI->new($self->cobrand->base_url)->host;
    join '-',
        $host,
        $self->on_updates ? ('updates') : (),
        map {
            my $value = $where{$_};
            (my $nosp = $value || '') =~ s/[ \/\\]/-/g;
            $nosp =~ s/[^[:ascii:]]//g;
            (defined $value and length $value) ? ($_, $nosp) : ()
        } sort keys %where
});

# Generation code

sub construct_rs_filter {
    my $self = shift;

    my $table_name = $self->on_updates ? 'problem' : 'me';

    my %where;
    $where{areas} = [ map { { 'like', "%,$_,%" } } @{$self->wards} ]
        if @{$self->wards};
    $where{"$table_name.category"} = $self->category
        if @{$self->category};

    my $all_states = $self->cobrand->call_hook('dashboard_export_include_all_states');
    if ( $self->state && FixMyStreet::DB::Result::Problem->fixed_states->{$self->state} ) { # Probably fixed - council
        $where{"$table_name.state"} = [ FixMyStreet::DB::Result::Problem->fixed_states() ];
    } elsif ( $self->state ) {
        $where{"$table_name.state"} = $self->state;
    } elsif ($all_states) {
        # Do nothing, want all states
    } else {
        $where{"$table_name.state"} = [ FixMyStreet::DB::Result::Problem->visible_states() ];
    }

    my $range = FixMyStreet::DateRange->new(
        start_date => $self->start_date,
        end_date => $self->end_date,
        formatter => FixMyStreet::DB->schema->storage->datetime_parser,
    );
    if ($all_states) {
        # Has to use created, because unconfirmed ones won't have a confirmed timestamp
        $where{"$table_name.created"} = $range->sql;
    } else {
        $where{"$table_name.confirmed"} = $range->sql;
    }

    my $rs = $self->on_updates ? $self->cobrand->updates : $self->cobrand->problems_on_dashboard;
    my $objects_rs = $rs->to_body($self->body)->search( \%where );

    if ($self->role_id) {
        $objects_rs = $objects_rs->search({
            'user_roles.role_id' => $self->role_id,
        }, {
            join => { contributed_by => 'user_roles' },
        });
    }

    $self->_set_objects_rs($objects_rs);
    return {
        params => \%where,
        objects_rs => $objects_rs,
    }
}

sub csv_parameters {
    my $self = shift;
    if ($self->on_updates) {
        $self->_csv_parameters_updates;
    } else {
        $self->_csv_parameters_problems;
    }
}

sub _csv_parameters_updates {
    my $self = shift;

    $self->objects_attrs({
        join => 'problem',
        order_by => ['me.confirmed', 'me.id'],
        '+columns' => ['problem.bodies_str'],
        cursor_page_size => 1000,
    });
    $self->_set_csv_headers([
        'Report ID', 'Update ID', 'Date', 'Status', 'Problem state',
        'Text', 'User Name', 'Reported As',
    ]);
    $self->_set_csv_columns([
        'problem_id', 'id', 'confirmed', 'state', 'problem_state',
        'text', 'user_name_display', 'reported_as',
    ]);
    $self->cobrand->call_hook(dashboard_export_updates_add_columns => $self);
}

sub _csv_parameters_problems {
    my $self = shift;

    my $groups = $self->cobrand->enable_category_groups ? 1 : 0;
    my $join = ['confirmed_comments', 'answered_questionnaires'];
    my $columns = ['confirmed_comments.id', 'confirmed_comments.problem_state', 'confirmed_comments.confirmed', 'confirmed_comments.mark_fixed',
        'answered_questionnaires.id', 'answered_questionnaires.whenanswered', 'answered_questionnaires.new_state'];
    if ($groups) {
        push @$join, 'contact';
        push @$columns, 'contact.id', 'contact.extra';
    }

    my $rs = $self->objects_rs->search(undef, {
        join => $join,
        collapse => 1,
        '+columns' => $columns,
        order_by => ['me.confirmed', 'me.id'],
        cursor_page_size => 1000,
    });
    $self->_set_objects_rs($rs);
    $self->_set_csv_headers([
        'Report ID',
        'Title',
        'Detail',
        'User Name',
        'Category',
        $groups ? ('Subcategory') : (),
        'Created',
        'Confirmed',
        'Acknowledged',
        'Fixed',
        'Closed',
        'Status',
        'Latitude', 'Longitude',
        'Query',
        'Ward',
        'Easting',
        'Northing',
        'Report URL',
        'Device Type',
        'Site Used',
        'Reported As',
    ]);
    $self->_set_csv_columns([
        'id',
        'title',
        'detail',
        'user_name_display',
        'category',
        $groups ? ('subcategory') : (),
        'created',
        'confirmed',
        'acknowledged',
        'fixed',
        'closed',
        'state',
        'latitude', 'longitude',
        'postcode',
        'wards',
        'local_coords_x',
        'local_coords_y',
        'url',
        'device_type',
        'cobrand',
        'reported_as',
    ]);
    $self->cobrand->call_hook(dashboard_export_problems_add_columns => $self);
}

=head2 generate_csv

Generates a CSV output to a file handler provided

=cut

sub generate_csv {
    my ($self, $handle, $exclude_header) = @_;

    my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
    $csv->print($handle, $self->csv_headers) unless $exclude_header;

    my $fixed_states = FixMyStreet::DB::Result::Problem->fixed_states;
    my $closed_states = FixMyStreet::DB::Result::Problem->closed_states;

    my %asked_for = map { $_ => 1 } @{$self->csv_columns};

    my $children = $self->body ? $self->body->area_children(1) : {};

    my $objects = $self->objects_rs;
    while ( my $obj = $objects->next ) {
        my $hashref = $obj->as_hashref(\%asked_for);

        $hashref->{user_name_display} = $obj->anonymous
            ? '(anonymous)' : $obj->name;

        if ($asked_for{acknowledged}) {
            my @updates = $obj->confirmed_comments->all;
            @updates = sort { $a->confirmed <=> $b->confirmed || $a->id <=> $b->id } @updates;
            for my $comment (@updates) {
                next unless $comment->problem_state || $comment->mark_fixed;
                my $problem_state = $comment->problem_state || '';
                next if $problem_state eq 'confirmed';
                $hashref->{acknowledged} //= $comment->confirmed;
                $hashref->{action_scheduled} //= $problem_state eq 'action scheduled' ? $comment->confirmed : undef;
                $hashref->{fixed} //= $fixed_states->{ $problem_state } || $comment->mark_fixed ?
                    $comment->confirmed : undef;
                if ($closed_states->{ $problem_state }) {
                    $hashref->{closed} = $comment->confirmed;
                    last;
                }
            }
            my @questionnaires = $obj->answered_questionnaires->all;
            @questionnaires = sort { $a->whenanswered <=> $b->whenanswered || $a->id <=> $b->id } @questionnaires;
            for my $questionnaire (@questionnaires) {
                my $problem_state = $questionnaire->new_state || '';
                if ($fixed_states->{ $problem_state }) {
                    if (!$hashref->{fixed} || $questionnaire->whenanswered lt $hashref->{fixed}) {
                        $hashref->{fixed} = $questionnaire->whenanswered;
                    }
                }
            }
        }

        if ($asked_for{wards}) {
            $hashref->{wards} = join ', ',
              map { $children->{$_}->{name} }
              grep { $children->{$_} }
              split ',', $hashref->{areas};
        }

        if ($obj->can('local_coords') && $asked_for{local_coords_x}) {
            ($hashref->{local_coords_x}, $hashref->{local_coords_y}) =
                $obj->local_coords;
        }

        if ($asked_for{subcategory}) {
            my $group = $obj->contact ? $obj->contact->groups : [];
            $group = join(',', @$group);
            if ($group) {
                $hashref->{subcategory} = $obj->category;
                $hashref->{category} = $group;
            }
        }

        my $base = $self->cobrand->base_url_for_report($obj->can('problem') ? $obj->problem : $obj);
        $hashref->{url} = join '', $base, $obj->url;

        if ($asked_for{device_type}) {
            $hashref->{device_type} = $obj->service || 'website';
        }
        $hashref->{cobrand} = $obj->cobrand;

        $hashref->{reported_as} = $obj->get_extra_metadata('contributed_as') || '';

        if (my $fn = $self->csv_extra_data) {
            my $extra = $fn->($obj, $hashref);
            $hashref = { %$hashref, %$extra };
        }

        $csv->print($handle, [
            @{$hashref}{
                @{$self->csv_columns}
            },
        ] );
    }
}

# Output code

sub cache_dir {
    my $self = shift;

    my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
    my $dir = $cfg ? $cfg->{UPLOAD_DIR} : FixMyStreet->config('UPLOAD_DIR');
    $dir = path($dir, "dashboard_csv")->absolute(FixMyStreet->path_to());
    my $subdir = $self->user ? $self->user->id : 0;
    $dir = $dir->child($subdir)->mkdir;
}

sub kick_off_process {
    my $self = shift;

    my $out = path($self->cache_dir, $self->filename . '.csv');
    my $file = path($out . '-part');
    return if $file->exists;
    $file->touch; # So status page shows it even if process takes short while to spin up

    my $cmd = FixMyStreet->path_to('bin/csv-export');
    $cmd .= ' --cobrand ' . $self->cobrand->moniker;
    $cmd .= " --out \Q$out\E";
    foreach (qw(type state start_date end_date)) {
        $cmd .= " --$_ " . quotemeta($self->$_) if $self->$_;
    }
    $cmd .= " --category " . join('::', map { quotemeta } @{$self->category}) if @{$self->category};
    foreach (qw(body user)) {
        $cmd .= " --$_ " . $self->$_->id if $self->$_;
    }
    $cmd .= " --role_id " . $self->role_id if $self->role_id;
    $cmd .= " --wards " . join(',', map { quotemeta } @{$self->wards}) if @{$self->wards};
    $cmd .= ' &' unless FixMyStreet->test_mode;

    system($cmd);
}

# Outputs relevant CSV HTTP headers, and then streams the CSV
sub generate_csv_http {
    my ($self, $c) = @_;
    $self->http_setup($c);
    $self->generate_csv($c->response);
}

sub http_setup {
    my ($self, $c) = @_;
    my $filename = $self->filename;

    $c->res->content_type('text/csv; charset=utf-8');
    $c->res->header('content-disposition' => "attachment; filename=\"${filename}.csv\"");

    # Emit a header (copying Drupal's naming) telling an intermediary (e.g.
    # Varnish) not to buffer the output. Varnish will need to know this, e.g.:
    #   if (beresp.http.Surrogate-Control ~ "BigPipe/1.0") {
    #     set beresp.do_stream = true;
    #     set beresp.ttl = 0s;
    #   }
    $c->res->header('Surrogate-Control' => 'content="BigPipe/1.0"');

    # Tell nginx not to buffer this response
    $c->res->header('X-Accel-Buffering' => 'no');

    # Define an empty body so the web view doesn't get added at the end
    $c->res->body("");
}

# Premade CVS generation code

has premade_dir => ( is => 'ro', default => sub {
    my $self = shift;
    my $cfg = FixMyStreet->config('PHOTO_STORAGE_OPTIONS');
    my $dir = $cfg ? $cfg->{UPLOAD_DIR} : FixMyStreet->config('UPLOAD_DIR');
    $dir = path($dir, "csv-export")->absolute(FixMyStreet->path_to())->mkdir;
});

sub premade_csv_filename {
    my $self = shift;
    return $self->premade_dir->child($self->body->id . ".csv");;
}

sub premade_csv_exists {
    my ($self) = @_;
    return unless $self->body;
    return unless $self->type eq 'problems';
    return $self->premade_csv_filename->exists;
}

=head2 filter_premade_csv

Generates the same output as construct_rs_filter/csv_parameters/generate_csv,
to the file handler provided, but does so by filtering a premade CSV file,
rather than querying the database.

=cut

sub filter_premade_csv {
    my ($self, $handle) = @_;
    my $fixed_states = FixMyStreet::DB::Result::Problem->fixed_states;

    my $first_column = 2;
    my $last_column = 0;
    my $state_column = 'Status';
    if ($self->cobrand->moniker eq 'bathnes' && !$self->user->has_body_permission_to('export_extra_columns')) {
        # Ignore last four columns for Bath if user does not have permission
        $last_column = 4;
    } elsif ($self->cobrand->moniker eq 'peterborough') {
        # Remove extra DB state column
        $first_column = 3;
        $state_column = 'DBState';
    }

    my $add_on_today = 0;
    my $today = DateTime->today(time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone);
    my $end_date = $self->end_date;
    if (!$end_date || $end_date ge $today->strftime('%Y-%m-%d')) {
        $add_on_today = 1;
        $end_date = $today->clone->subtract(days => 1)->strftime('%Y-%m-%d');
    }

    my $range = FixMyStreet::DateRange->new(
        start_date => $self->start_date,
        end_date => $end_date,
        formatter => FixMyStreet::DB->schema->storage->datetime_parser,
    );

    my $all_states = $self->cobrand->call_hook('dashboard_export_include_all_states');
    my $wards_re = join ('|', @{$self->wards});
    my $category_re = join('|', map { quotemeta } @{$self->category});

    my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
    open my $fh, "<:encoding(utf8)", $self->premade_csv_filename;
    my $arr = $csv->getline($fh);
    $csv->print($handle, [ @$arr[2..@$arr-$last_column-1] ]);
    my $row = {};
    $csv->bind_columns(\@{$row}{@$arr});
    while ($csv->getline($fh)) {

        # Perform the same filtering as what construct_rs_filter does
        # by skipping rows from the CSV file that do not match

        next if $wards_re && $row->{Areas} !~ /,($wards_re),/;

        my $category = $row->{Subcategory} || $row->{Category};
        next if @{$self->category} && $category !~ /^($category_re)$/;

        if ( $self->state && $fixed_states->{$self->state} ) { # Probably fixed - council
            next unless $fixed_states->{$row->{$state_column}};
        } elsif ( $self->state ) {
            next if $row->{$state_column} ne $self->state;
        }

        if ($all_states) {
            # Has to use created, because unconfirmed ones won't have a confirmed timestamp
            next if $row->{Created} lt $range->start_formatted;
            next if $range->end_formatted && $row->{Created} ge $range->end_formatted;
        } else {
            next if $row->{Confirmed} lt $range->start_formatted;
            next if $range->end_formatted && $row->{Confirmed} ge $range->end_formatted;
        }

        if ($self->role_id) {
            my %roles = map { $_ => 1 } split ',', $row->{Roles};
            next unless $roles{$self->role_id};
        }

        # As with generate_csv, output the data to the filehandle. All extra
        # fields etc have already been included. Exclude the first two columns,
        # Areas and Roles, that were only included for the filtering above
        $csv->print($handle, [ (@{$row}{@$arr})[$first_column..@$arr-$last_column-1] ]);
    }

    if ($add_on_today) {
        # Add in any information from today the 'live' way
        $self->_set_start_date($today->strftime('%Y-%m-%d'));
        $self->construct_rs_filter;
        $self->csv_parameters;
        $self->generate_csv($handle, 1);
    }
}

# Outputs relevant CSV HTTP headers, and then streams the CSV
sub filter_premade_csv_http {
    my ($self, $c) = @_;
    $self->http_setup($c);
    $self->filter_premade_csv($c->response);
}

sub _extra_field {
    my ($self, $report, $key) = @_;
    if ($self->dbi) {
        return $key ? $report->{extra}{_field_value}{$key} : ($report->{extra}{_fields} || []);
    } else {
        return $key ? $report->get_extra_field_value($key) : $report->get_extra_fields;
    }
}

sub _extra_metadata {
    my ($self, $report, $key) = @_;
    if ($self->dbi) {
        return $key ? $report->{extra}{$key} : $report->{extra};
    } else {
        return $report->get_extra_metadata($key);
    }
}

1;
