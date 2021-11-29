package FixMyStreet::Reporting;

use DateTime;
use Moo;
use Path::Tiny;
use Text::CSV;
use Types::Standard qw(ArrayRef CodeRef Enum HashRef InstanceOf Int Maybe Str);
use FixMyStreet::DB;

# What are we reporting on

has type => ( is => 'ro', isa => Enum['problems','updates'] );
has on_problems => ( is => 'lazy', default => sub { $_[0]->type eq 'problems' } );
has on_updates => ( is => 'lazy', default => sub { $_[0]->type eq 'updates' } );

# Filters to restrict the reporting to

has body => ( is => 'ro', isa => Maybe[InstanceOf['FixMyStreet::DB::Result::Body']] );
has wards => ( is => 'ro', isa => ArrayRef[Int], default => sub { [] } );
has category => ( is => 'ro', isa => Maybe[Str] );
has state => ( is => 'ro', isa => Maybe[Str] );
has start_date => ( is => 'ro',
    isa => Str,
    default => sub {
        my $days30 = DateTime->now(time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone)->subtract(days => 30);
        $days30->truncate( to => 'day' );
        $days30->strftime('%Y-%m-%d');
    }
);
has end_date => ( is => 'ro', isa => Maybe[Str] );

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
# local_coords_x, local_coords_y, url, subcategory, site_used, reported_as)
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
        category => $self->category,
        state => $self->state,
        ward => join(',', @{$self->wards}),
        start_date => $self->start_date,
        end_date => $self->end_date,
    );
    $where{body} = $self->body->id if $self->body;
    my $host = URI->new($self->cobrand->base_url)->host;
    join '-',
        $host,
        $self->on_updates ? ('updates') : (),
        map {
            my $value = $where{$_};
            (my $nosp = $value || '') =~ s/[ \/\\]/-/g;
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
        if $self->category;

    if ( $self->state && FixMyStreet::DB::Result::Problem->fixed_states->{$self->state} ) { # Probably fixed - council
        $where{"$table_name.state"} = [ FixMyStreet::DB::Result::Problem->fixed_states() ];
    } elsif ( $self->state ) {
        $where{"$table_name.state"} = $self->state;
    } else {
        $where{"$table_name.state"} = [ FixMyStreet::DB::Result::Problem->visible_states() ];
    }

    my $range = FixMyStreet::DateRange->new(
        start_date => $self->start_date,
        end_date => $self->end_date,
        formatter => FixMyStreet::DB->schema->storage->datetime_parser,
    );
    $where{"$table_name.confirmed"} = $range->sql;

    my $rs = $self->on_updates ? $self->cobrand->updates : $self->cobrand->problems;
    my $objects_rs = $rs->to_body($self->body)->search( \%where );
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
    my $join = ['comments'];
    my $columns = ['comments.id', 'comments.problem_state', 'comments.state', 'comments.confirmed', 'comments.mark_fixed'];
    if ($groups) {
        push @$join, 'contact';
        push @$columns, 'contact.id', 'contact.extra';
    }
    $self->objects_attrs({
        join => $join,
        collapse => 1,
        '+columns' => $columns,
        order_by => ['me.confirmed', 'me.id'],
        cursor_page_size => 1000,
    });
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
        'site_used',
        'reported_as',
    ]);
    $self->cobrand->call_hook(dashboard_export_problems_add_columns => $self);
}

=head2 generate_csv

Generates a CSV output to a file handler provided

=cut

sub generate_csv {
    my ($self, $handle) = @_;

    my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
    $csv->print($handle, $self->csv_headers);

    my $fixed_states = FixMyStreet::DB::Result::Problem->fixed_states;
    my $closed_states = FixMyStreet::DB::Result::Problem->closed_states;

    my %asked_for = map { $_ => 1 } @{$self->csv_columns};

    my $children = $self->body ? $self->body->first_area_children : {};

    my $objects = $self->objects_rs;
    while ( my $obj = $objects->next ) {
        my $hashref = $obj->as_hashref(\%asked_for);

        $hashref->{user_name_display} = $obj->anonymous
            ? '(anonymous)' : $obj->name;

        if ($asked_for{acknowledged}) {
            for my $comment ($obj->comments->search(undef, { order_by => ['confirmed', 'id'] })) {
                my $problem_state = $comment->problem_state or next;
                next unless $comment->state eq 'confirmed';
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
        $hashref->{site_used} = $obj->cobrand;

        $hashref->{reported_as} = $obj->get_extra_metadata('contributed_as') || '';

        if (my $fn = $self->csv_extra_data) {
            my $extra = $fn->($obj);
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
    $dir = $dir->child($subdir);
    $dir->mkpath;
    $dir;
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
    foreach (qw(type category state start_date end_date)) {
        $cmd .= " --$_ " . quotemeta($self->$_) if $self->$_;
    }
    foreach (qw(body user)) {
        $cmd .= " --$_ " . $self->$_->id if $self->$_;
    }
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

1;
