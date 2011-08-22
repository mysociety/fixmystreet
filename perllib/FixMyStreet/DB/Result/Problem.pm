package FixMyStreet::DB::Result::Problem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("problem");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "problem_id_seq",
  },
  "postcode",
  { data_type => "text", is_nullable => 0 },
  "latitude",
  { data_type => "double precision", is_nullable => 0 },
  "longitude",
  { data_type => "double precision", is_nullable => 0 },
  "council",
  { data_type => "text", is_nullable => 1 },
  "areas",
  { data_type => "text", is_nullable => 0 },
  "category",
  { data_type => "text", default_value => "Other", is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 0 },
  "detail",
  { data_type => "text", is_nullable => 0 },
  "photo",
  { data_type => "bytea", is_nullable => 1 },
  "used_map",
  { data_type => "boolean", is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "anonymous",
  { data_type => "boolean", is_nullable => 0 },
  "external_id",
  { data_type => "text", is_nullable => 1 },
  "external_body",
  { data_type => "text", is_nullable => 1 },
  "external_team",
  { data_type => "text", is_nullable => 1 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"ms_current_timestamp()",
    is_nullable   => 0,
  },
  "confirmed",
  { data_type => "timestamp", is_nullable => 1 },
  "state",
  { data_type => "text", is_nullable => 0 },
  "lang",
  { data_type => "text", default_value => "en-gb", is_nullable => 0 },
  "service",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "cobrand",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "cobrand_data",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "lastupdate",
  {
    data_type     => "timestamp",
    default_value => \"ms_current_timestamp()",
    is_nullable   => 0,
  },
  "whensent",
  { data_type => "timestamp", is_nullable => 1 },
  "send_questionnaire",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "extra",
  { data_type => "text", is_nullable => 1 },
  "flagged",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "comments",
  "FixMyStreet::DB::Result::Comment",
  { "foreign.problem_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "user",
  "FixMyStreet::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);
__PACKAGE__->has_many(
  "questionnaires",
  "FixMyStreet::DB::Result::Questionnaire",
  { "foreign.problem_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-07-29 16:26:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ifvx9FOlbui66hPyzNIAPA

# Add fake relationship to stored procedure table
__PACKAGE__->has_one(
  "nearby",
  "FixMyStreet::DB::Result::Nearby",
  { "foreign.problem_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->filter_column(
    extra => {
        filter_from_storage => sub {
            my $self = shift;
            my $ser  = shift;
            return undef unless defined $ser;
            my $h = new IO::String($ser);
            return RABX::wire_rd($h);
        },
        filter_to_storage => sub {
            my $self = shift;
            my $data = shift;
            my $ser  = '';
            my $h    = new IO::String($ser);
            RABX::wire_wr( $data, $h );
            return $ser;
        },
    }
);
use DateTime::TimeZone;
use Image::Size;
use Moose;
use namespace::clean -except => [ 'meta' ];
use Utils;
use RABX;

with 'FixMyStreet::Roles::Abuser';

=head2

    @states = FixMyStreet::DB::Problem::open_states();

Get a list or states that are regarded as open. If called in
array context then returns an array of names, otherwise returns a
HASHREF.

=cut

sub open_states {
    my $states = {
        'confirmed'     => 1,
        'investigating' => 1,
        'planned'       => 1,
        'in progress'   => 1,
    };

    return wantarray ? keys %{$states} : $states;
}

=head2

    @states = FixMyStreet::DB::Problem::fixed_states();

Get a list or states that should be regarded as fixed. If called in
array context then returns an array of names, otherwise returns a
HASHREF.

=cut

sub fixed_states {
    my $states = {
        'fixed'           => 1,
        'fixed - user'    => 1,
        'fixed - council' => 1,
    };

    return wantarray ? keys %{ $states } : $states;
}

=head2

    @states = FixMyStreet::DB::Problem::closed_states();

Get a list or states that should be regarded as closed. If called in
array context then returns an array of names, otherwise returns a
HASHREF.

=cut

sub closed_states {
    my $states = {
        'closed'          => 1,
    };

    return wantarray ? keys %{$states} : $states;
}


=head2

    @states = FixMyStreet::DB::Problem::visible_states();

Get a list or states that should be visible on the site. If called in
array context then returns an array of names, otherwise returns a
HASHREF.

=cut

sub visible_states {
    my $states = {
        'confirmed'       => 1,
        'planned'         => 1,
        'investigating'   => 1,
        'in progress'     => 1,
        'fixed'           => 1,
        'fixed - council' => 1,
        'fixed - user'    => 1,
        'closed'          => 1,
    };

    return wantarray ? keys %{$states} : $states;
}


my $tz = DateTime::TimeZone->new( name => "local" );

sub confirmed_local {
    my $self = shift;

    return $self->confirmed
      ? $self->confirmed->set_time_zone($tz)
      : $self->confirmed;
}

sub created_local {
    my $self = shift;

    return $self->created
      ? $self->created->set_time_zone($tz)
      : $self->created;
}

sub whensent_local {
    my $self = shift;

    return $self->whensent
      ? $self->whensent->set_time_zone($tz)
      : $self->whensent;
}

sub lastupdate_local {
    my $self = shift;

    return $self->lastupdate
      ? $self->lastupdate->set_time_zone($tz)
      : $self->lastupdate;
}

around service => sub {
    my ( $orig, $self ) = ( shift, shift );
    my $s = $self->$orig(@_);
    $s =~ s/_/ /g;
    return $s;
};

=head2 check_for_errors

    $error_hashref = $problem->check_for_errors();

Look at all the fields and return a hashref with all errors found, keyed on the
field name. This is intended to be passed back to the form to display the
errors.

TODO - ideally we'd pass back error codes which would be humanised in the
templates (eg: 'missing','email_not_valid', etc).

=cut

sub check_for_errors {
    my $self = shift;

    my %errors = ();

    $errors{title} = _('Please enter a subject')
      unless $self->title =~ m/\S/;

    $errors{detail} = _('Please enter some details')
      unless $self->detail =~ m/\S/;

    $errors{council} = _('No council selected')
      unless $self->council
          && $self->council =~ m/^(?:-1|[\d,]+(?:\|[\d,]+)?)$/;

    if ( !$self->name || $self->name !~ m/\S/ ) {
        $errors{name} = _('Please enter your name');
    }
    elsif (length( $self->name ) < 5
        || $self->name !~ m/\s/
        || $self->name =~ m/\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i )
    {
        $errors{name} = _(
'Please enter your full name, councils need this information - if you do not wish your name to be shown on the site, untick the box'
        );
    }

    if (   $self->category
        && $self->category eq _('-- Pick a category --') )
    {
        $errors{category} = _('Please choose a category');
        $self->category(undef);
    }
    elsif ($self->category
        && $self->category eq _('-- Pick a property type --') )
    {
        $errors{category} = _('Please choose a property type');
        $self->category(undef);
    }

    return \%errors;
}

=head2 confirm

    $bool = $problem->confirm(  );
    $problem->update;


Set the state to 'confirmed' and put current time into 'confirmed' field. This
is a no-op if the report is already confirmed.

NOTE - does not update storage - call update or insert to do that.

=cut

sub confirm {
    my $self = shift;

    return if $self->state eq 'confirmed';

    $self->state('confirmed');
    $self->confirmed( \'ms_current_timestamp()' );
    return 1;
}

=head2 councils

Returns an arrayref of councils to which a report was sent.

=cut

sub councils {
    my $self = shift;
    return [] unless $self->council;
    (my $council = $self->council) =~ s/\|.*$//;
    my @council = split( /,/, $council );
    return \@council;
}

=head2 url

Returns a URL for this problem report.

=cut

sub url {
    my $self = shift;
    return "/report/" . $self->id;
}

=head2 get_photo_params

Returns a hashref of details of any attached photo for use in templates.
Hashref contains height, width and url keys.

=cut

sub get_photo_params {
    my $self = shift;

    return {} unless $self->photo;

    my $photo = {};
    ( $photo->{width}, $photo->{height} ) =
      Image::Size::imgsize( \$self->photo );
    $photo->{url} = '/photo?id=' . $self->id;

    return $photo;
}

=head2 is_open

Returns 1 if the problem is in a open state otherwise 0.

=cut

sub is_open {
    my $self = shift;

    return exists $self->open_states->{ $self->state } ? 1 : 0;
}


=head2 is_fixed

Returns 1 if the problem is in a fixed state otherwise 0.

=cut

sub is_fixed {
    my $self = shift;

    return exists $self->fixed_states->{ $self->state } ? 1 : 0;
}

=head2 is_closed

Returns 1 if the problem is in a closed state otherwise 0.

=cut

sub is_closed {
    my $self = shift;

    return exists $self->closed_states->{ $self->state } ? 1 : 0;
}

=head2 is_visible

Returns 1 if the problem should be displayed on the site otherwise 0.

=cut

sub is_visible {
    my $self = shift;

    return exists $self->visible_states->{ $self->state } ? 1 : 0;
}

=head2 meta_line

Returns a string to be used on a problem report page, describing some of the
meta data about the report.

=cut

sub meta_line {
    my ( $problem, $c ) = @_;

    my $date_time =
      Utils::prettify_epoch( $problem->confirmed_local->epoch );
    my $meta = '';

    # FIXME Should be in cobrand
    if ($c->cobrand->moniker eq 'emptyhomes') {

        my $category = _($problem->category);
        utf8::decode($category);
        if ($problem->anonymous) {
            $meta = sprintf(_('%s, reported anonymously at %s'), $category, $date_time);
        } else {
            $meta = sprintf(_('%s, reported by %s at %s'), $category, $problem->name, $date_time);
        }

    } else {

        if ( $problem->anonymous ) {
            if (    $problem->service
                and $problem->category && $problem->category ne _('Other') )
            {
                $meta =
                sprintf( _('Reported by %s in the %s category anonymously at %s'),
                    $problem->service, $problem->category, $date_time );
            }
            elsif ( $problem->service ) {
                $meta = sprintf( _('Reported by %s anonymously at %s'),
                    $problem->service, $date_time );
            }
            elsif ( $problem->category and $problem->category ne _('Other') ) {
                $meta = sprintf( _('Reported in the %s category anonymously at %s'),
                    $problem->category, $date_time );
            }
            else {
                $meta = sprintf( _('Reported anonymously at %s'), $date_time );
            }
        }
        else {
            if (    $problem->service
                and $problem->category && $problem->category ne _('Other') )
            {
                $meta = sprintf(
                    _('Reported by %s in the %s category by %s at %s'),
                    $problem->service, $problem->category,
                    $problem->name,    $date_time
                );
            }
            elsif ( $problem->service ) {
                $meta = sprintf( _('Reported by %s by %s at %s'),
                    $problem->service, $problem->name, $date_time );
            }
            elsif ( $problem->category and $problem->category ne _('Other') ) {
                $meta = sprintf( _('Reported in the %s category by %s at %s'),
                    $problem->category, $problem->name, $date_time );
            }
            else {
                $meta =
                sprintf( _('Reported by %s at %s'), $problem->name, $date_time );
            }
        }

    }

    $meta .= $c->cobrand->extra_problem_meta_text($problem);
    $meta .= '; ' . _('the map was not used so pin location may be inaccurate')
        unless $problem->used_map;

    return $meta;
}

sub body {
    my ( $problem, $c ) = @_;
    my $body;
    if ($problem->external_body) {
        $body = $problem->external_body;
    } else {
        (my $council = $problem->council) =~ s/\|.*//g;
        my @councils = split( /,/, $council );
        my $areas_info = mySociety::MaPit::call('areas', \@councils);
        $body = join( _(' and '),
            map {
                my $name = $areas_info->{$_}->{name};
                if (mySociety::Config::get('AREA_LINKS_FROM_PROBLEMS')) {
                    '<a href="'
                    . $c->uri_for( '/reports/' . $c->cobrand->short_name( $areas_info->{$_} ) )
                    . '">' . $name . '</a>';
                } else {
                    $name;
                }
            } @councils
        );
    }
    return $body;
}

# TODO Some/much of this could be moved to the template
sub duration_string {
    my ( $problem, $c ) = @_;
    my $body = $problem->body( $c );
    return sprintf(_('Sent to %s %s later'), $body,
        Utils::prettify_duration($problem->whensent_local->epoch - $problem->confirmed_local->epoch, 'minute')
    );
}

=head2 update_from_open311_service_request

    $p->update_from_open311_service_request( $request, $council_details, $system_user );

Updates the problem based on information in the passed in open311 request. If the request
has an older update time than the problem's lastupdate time then nothing happens.

Otherwise a comment will be created if there is status update text in the open311 request.
If the open311 request has a state of closed then the problem will be marked as fixed.

NB: a comment will always be created if the problem is being marked as fixed.

Fixed problems will not be re-opened by this method.

=cut

sub update_from_open311_service_request {
    my ( $self, $request, $council_details, $system_user ) = @_;

    my ( $updated, $status_notes );

    if ( ! ref $request->{updated_datetime} ) {
        $updated = $request->{updated_datetime};
    }

    if ( ! ref $request->{status_notes} ) {
        $status_notes = $request->{status_notes};
    }

    my $update = FixMyStreet::App->model('DB::Comment')->new(
        {
            problem_id => $self->id,
            state      => 'confirmed',
            created    => $updated || \'ms_current_timestamp()',
            confirmed => \'ms_current_timestamp()',
            text      => $status_notes,
            mark_open => 0,
            mark_fixed => 0,
            user => $system_user,
            anonymous => 0,
            name => $council_details->{name},
        }
    );


    my $w3c = DateTime::Format::W3CDTF->new;
    my $req_time = $w3c->parse_datetime( $request->{updated_datetime} );

    # set a timezone here as the $req_time will have one and if we don't
    # use a timezone then the date comparisons are invalid.
    # of course if local timezone is not the one that went into the data
    # base then we're also in trouble
    my $lastupdate = $self->lastupdate;
    $lastupdate->set_time_zone( DateTime::TimeZone->new( name => 'local' ) );

    # update from open311 is older so skip
    if ( $req_time < $lastupdate ) {
        return 0;
    }

    if ( $request->{status} eq 'closed' ) {
        if ( $self->state ne 'fixed' ) {
            $self->state('fixed');
            $update->mark_fixed(1);

            if ( !$status_notes ) {
                # FIXME - better text here
                $status_notes = _('Closed by council');
            }
        }
    }

    if ( $status_notes ) {
        $update->text( $status_notes );
        $self->lastupdate( $req_time );
        $self->update;
        $update->insert;
    }

    return 1;
}

# we need the inline_constructor bit as we don't inherit from Moose
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
