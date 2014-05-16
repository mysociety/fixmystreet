use utf8;
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
  "bodies_str",
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
  "geocode",
  { data_type => "bytea", is_nullable => 1 },
  "send_fail_count",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "send_fail_reason",
  { data_type => "text", is_nullable => 1 },
  "send_fail_timestamp",
  { data_type => "timestamp", is_nullable => 1 },
  "send_method_used",
  { data_type => "text", is_nullable => 1 },
  "non_public",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "external_source",
  { data_type => "text", is_nullable => 1 },
  "external_source_id",
  { data_type => "text", is_nullable => 1 },
  "interest_count",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "subcategory",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "comments",
  "FixMyStreet::DB::Result::Comment",
  { "foreign.problem_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "questionnaires",
  "FixMyStreet::DB::Result::Questionnaire",
  { "foreign.problem_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "user",
  "FixMyStreet::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-09-10 17:11:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:U/4BT8EGfcCLKA/7LX+qyQ

# Add fake relationship to stored procedure table
__PACKAGE__->has_one(
  "nearby",
  "FixMyStreet::DB::Result::Nearby",
  { "foreign.problem_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->load_components("+FixMyStreet::DB::RABXColumn");
__PACKAGE__->rabx_column('extra');
__PACKAGE__->rabx_column('geocode');

use DateTime::TimeZone;
use Image::Size;
use Moose;
use namespace::clean -except => [ 'meta' ];
use Utils;

with 'FixMyStreet::Roles::Abuser';

=head2

    @states = FixMyStreet::DB::Problem::open_states();

Get a list or states that are regarded as open. If called in
array context then returns an array of names, otherwise returns a
HASHREF.

=cut

sub open_states {
    my $states = {
        'confirmed'        => 1,
        'investigating'    => 1,
        'in progress'      => 1,
        'planned'          => 1,
        'action scheduled' => 1,
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
        'closed'                      => 1,
        'unable to fix'               => 1,
        'not responsible'             => 1,
        'duplicate'                   => 1,
        'internal referral'           => 1,
    };

    return wantarray ? keys %{$states} : $states;
}


=head2

    @states = FixMyStreet::DB::Problem::visible_states();

Get a list of states that should be visible on the site. If called in
array context then returns an array of names, otherwise returns a
HASHREF.

=cut

my $visible_states = {
    'confirmed'                   => 1,
    'investigating'               => 1,
    'in progress'                 => 1,
    'planned'                     => 1,
    'action scheduled'            => 1,
    'fixed'                       => 1,
    'fixed - council'             => 1,
    'fixed - user'                => 1,
    'unable to fix'               => 1,
    'not responsible'             => 1,
    'duplicate'                   => 1,
    'closed'                      => 1,
    'internal referral'           => 1,
};
sub visible_states {
    return wantarray ? keys %{$visible_states} : $visible_states;
}
sub visible_states_add_unconfirmed {
    $visible_states->{unconfirmed} = 1;
}

=head2

    @states = FixMyStreet::DB::Problem::all_states();

Get a list of all states that a problem can have. If called in
array context then returns an array of names, otherwise returns a
HASHREF.

=cut

sub all_states {
    my $states = {
        'hidden'                      => 1,
        'partial'                     => 1,
        'unconfirmed'                 => 1,
        'confirmed'                   => 1,
        'investigating'               => 1,
        'in progress'                 => 1,
        'planned'                     => 1,
        'action scheduled'            => 1,
        'fixed'                       => 1,
        'fixed - council'             => 1,
        'fixed - user'                => 1,
        'unable to fix'               => 1,
        'not responsible'             => 1,
        'duplicate'                   => 1,
        'closed'                      => 1,
        'internal referral'           => 1,
    };

    return wantarray ? keys %{$states} : $states;
}

=head2

    @states = FixMyStreet::DB::Problem::council_states();

Get a list of states that are availble to council users. If called in
array context then returns an array of names, otherwise returns a
HASHREF.

=cut
sub council_states {
    my $states = {
        'confirmed'                   => 1,
        'investigating'               => 1,
        'action scheduled'            => 1,
        'in progress'                 => 1,
        'fixed - council'             => 1,
        'unable to fix'               => 1,
        'not responsible'             => 1,
        'duplicate'                   => 1,
        'internal referral'           => 1,
    };

    return wantarray ? keys %{$states} : $states;
}

my $tz = DateTime::TimeZone->new( name => "local" );

my $tz_f;
$tz_f = DateTime::TimeZone->new( name => FixMyStreet->config('TIME_ZONE') )
    if FixMyStreet->config('TIME_ZONE');

my $stz = sub {
    my ( $orig, $self ) = ( shift, shift );
    my $s = $self->$orig(@_);
    return $s unless $s && UNIVERSAL::isa($s, "DateTime");
    $s->set_time_zone($tz);
    $s->set_time_zone($tz_f) if $tz_f;
    return $s;
};

around created => $stz;
around confirmed => $stz;
around whensent => $stz;
around lastupdate => $stz;

around service => sub {
    my ( $orig, $self ) = ( shift, shift );
    my $s = $self->$orig(@_);
    $s =~ s/_/ /g;
    return $s;
};

sub title_safe {
    my $self = shift;
    return _('Awaiting moderation') if $self->cobrand eq 'zurich' && $self->state eq 'unconfirmed';
    return $self->title;
}

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

    $errors{bodies} = _('No council selected')
      unless $self->bodies_str
          && $self->bodies_str =~ m/^(?:-1|[\d,]+(?:\|[\d,]+)?)$/;

    if ( !$self->name || $self->name !~ m/\S/ ) {
        $errors{name} = _('Please enter your name');
    }
    elsif (length( $self->name ) < 5
        || $self->name !~ m/\s/
        || $self->name =~ m/\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i )
    {
        $errors{name} = _(
'Please enter your full name, councils need this information – if you do not wish your name to be shown on the site, untick the box below'
        ) unless $self->cobrand eq 'emptyhomes';
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

    if ( $self->bodies_str && $self->detail ) {
        # Custom character limit:
        # Bromley Council
        if ( $self->bodies_str eq '2482' && length($self->detail) > 1750 ) {
            $errors{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), 1750 );
        }
        # Oxfordshire
        if ( $self->bodies_str eq '2237' && length($self->detail) > 1700 ) {
            $errors{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), 1700 );
        }
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

sub bodies_str_ids {
    my $self = shift;
    return unless $self->bodies_str;
    (my $bodies = $self->bodies_str) =~ s/\|.*$//;
    my @bodies = split( /,/, $bodies );
    return \@bodies;
}

=head2 bodies

Returns a hashref of bodies to which a report was sent.

=cut

sub bodies($) {
    my $self = shift;
    return {} unless $self->bodies_str;
    my $bodies = $self->bodies_str_ids;
    my @bodies = FixMyStreet::App->model('DB::Body')->search({ id => $bodies })->all;
    return { map { $_->id => $_ } @bodies };
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

=cut

sub get_photo_params {
    my $self = shift;
    return FixMyStreet::App::get_photo_params($self, 'id');
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

    my $date_time = Utils::prettify_dt( $problem->confirmed );
    my $meta = '';

    # FIXME Should be in cobrand
    if ($c->cobrand->moniker eq 'emptyhomes') {

        my $category = _($problem->category);
        utf8::decode($category);
        $meta = sprintf(_('%s, reported at %s'), $category, $date_time);

    } else {

        if ( $problem->anonymous ) {
            if (    $problem->service
                and $problem->category && $problem->category ne _('Other') )
            {
                $meta =
                sprintf( _('Reported via %s in the %s category anonymously at %s'),
                    $problem->service, $problem->category, $date_time );
            }
            elsif ( $problem->service ) {
                $meta = sprintf( _('Reported via %s anonymously at %s'),
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
                    _('Reported via %s in the %s category by %s at %s'),
                    $problem->service, $problem->category,
                    $problem->name,    $date_time
                );
            }
            elsif ( $problem->service ) {
                $meta = sprintf( _('Reported via %s by %s at %s'),
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

    return $meta;
}

sub body {
    my ( $problem, $c ) = @_;
    my $body;
    if ($problem->external_body) {
        if ($problem->cobrand eq 'zurich') {
            $body = $c->model('DB::Body')->find({ id => $problem->external_body });
        } else {
            $body = $problem->external_body;
        }
    } else {
        my $bodies = $problem->bodies;
        $body = join( _(' and '),
            map {
                my $name = $_->name;
                if ($c and mySociety::Config::get('AREA_LINKS_FROM_PROBLEMS')) {
                    '<a href="' . $_->url($c) . '">' . $name . '</a>';
                } else {
                    $name;
                }
            } values %$bodies
        );
    }
    return $body;
}

# returns true if the external id is the council's ref, i.e., useful to publish it
# (by way of an example, the barnet send method returns a useful reference when
# it succeeds, so that is the ref we should show on the problem report page).
#     Future: this is installation-dependent so maybe should be using the contact
#             data to determine if the external id is public on a council-by-council basis.
#     Note:   this only makes sense when called on a problem that has been sent!
sub can_display_external_id {
    my $self = shift;
    if ($self->external_id && $self->send_method_used && 
        ($self->send_method_used eq 'barnet' || $self->bodies_str =~ /2237/)) {
        return 1;
    }
    return 0;    
}

# TODO Some/much of this could be moved to the template

# either: 
#   "sent to council 3 mins later"
#   "[Council name] ref: XYZ"
# or
#   "sent to council 3 mins later, their ref: XYZ"
#
# Note: some silliness with pronouns and the adjacent comma mean this is
#       being presented as a single string rather than two
sub processed_summary_string {
    my ( $problem, $c ) = @_;
    my ($duration_clause, $external_ref_clause);
    if ($problem->whensent) {
        $duration_clause = $problem->duration_string($c);
    }
    if ($problem->can_display_external_id) {
        if ($duration_clause) {
            $external_ref_clause = sprintf(_('council ref:&nbsp;%s'), $problem->external_id);
        } else {
            $external_ref_clause = sprintf(_('%s ref:&nbsp;%s'), $problem->external_body, $problem->external_id);
        }
    }
    if ($duration_clause and $external_ref_clause) {
        return "$duration_clause, $external_ref_clause"
    } else { 
        return $duration_clause || $external_ref_clause
    }
}

sub duration_string {
    my ( $problem, $c ) = @_;
    my $body = $problem->body( $c );
    return sprintf(_('Sent to %s %s later'), $body,
        Utils::prettify_duration($problem->whensent->epoch - $problem->confirmed->epoch, 'minute')
    );
}

sub local_coords {
    my $self = shift;
    if ($self->cobrand eq 'zurich') {
        my ($x, $y) = Geo::Coordinates::CH1903::from_latlon($self->latitude, $self->longitude);
        return ( int($x+0.5), int($y+0.5) );
    }
}

=head2 update_from_open311_service_request

    $p->update_from_open311_service_request( $request, $body, $system_user );

Updates the problem based on information in the passed in open311 request
(standard, not the extension that uses GetServiceRequestUpdates) . If the
request has an older update time than the problem's lastupdate time then
nothing happens.

Otherwise a comment will be created if there is status update text in the
open311 request. If the open311 request has a state of closed then the problem
will be marked as fixed.

NB: a comment will always be created if the problem is being marked as fixed.

Fixed problems will not be re-opened by this method.

=cut

sub update_from_open311_service_request {
    my ( $self, $request, $body, $system_user ) = @_;

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
            name => $body->name,
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

sub update_send_failed {
    my $self = shift;
    my $msg  = shift;

    $self->update( {
        send_fail_count => $self->send_fail_count + 1,
        send_fail_timestamp => \'ms_current_timestamp()',
        send_fail_reason => $msg
    } );
}

sub as_hashref {
    my $self = shift;
    my $c    = shift;

    return {
        id        => $self->id,
        title     => $self->title,
        category  => $self->category,
        detail    => $self->detail,
        latitude  => $self->latitude,
        longitude => $self->longitude,
        postcode  => $self->postcode,
        state     => $self->state,
        state_t   => _( $self->state ),
        used_map  => $self->used_map,
        is_fixed  => $self->fixed_states->{ $self->state } ? 1 : 0,
        photo     => $self->get_photo_params,
        meta      => $self->confirmed ? $self->meta_line( $c ) : '',
        confirmed_pp => $self->confirmed ? $c->cobrand->prettify_dt( $self->confirmed ): '',
        created_pp => $c->cobrand->prettify_dt( $self->created ),
    };
}

# we need the inline_constructor bit as we don't inherit from Moose
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
