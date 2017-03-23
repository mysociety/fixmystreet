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
  "title",
  { data_type => "text", is_nullable => 0 },
  "detail",
  { data_type => "text", is_nullable => 0 },
  "photo",
  { data_type => "bytea", is_nullable => 1 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "state",
  { data_type => "text", is_nullable => 0 },
  "whensent",
  { data_type => "timestamp", is_nullable => 1 },
  "used_map",
  { data_type => "boolean", is_nullable => 0 },
  "bodies_str",
  { data_type => "text", is_nullable => 1 },
  "anonymous",
  { data_type => "boolean", is_nullable => 0 },
  "category",
  { data_type => "text", default_value => "Other", is_nullable => 0 },
  "confirmed",
  { data_type => "timestamp", is_nullable => 1 },
  "send_questionnaire",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "lastupdate",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "areas",
  { data_type => "text", is_nullable => 0 },
  "service",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "lang",
  { data_type => "text", default_value => "en-gb", is_nullable => 0 },
  "cobrand",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "cobrand_data",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "latitude",
  { data_type => "double precision", is_nullable => 0 },
  "longitude",
  { data_type => "double precision", is_nullable => 0 },
  "external_id",
  { data_type => "text", is_nullable => 1 },
  "external_body",
  { data_type => "text", is_nullable => 1 },
  "external_team",
  { data_type => "text", is_nullable => 1 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "flagged",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "extra",
  { data_type => "text", is_nullable => 1 },
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
  "bodies_missing",
  { data_type => "text", is_nullable => 1 },
  "response_priority_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "defect_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "comments",
  "FixMyStreet::DB::Result::Comment",
  { "foreign.problem_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "defect_type",
  "FixMyStreet::DB::Result::DefectType",
  { id => "defect_type_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "moderation_original_datas",
  "FixMyStreet::DB::Result::ModerationOriginalData",
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
  "response_priority",
  "FixMyStreet::DB::Result::ResponsePriority",
  { id => "response_priority_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "user",
  "FixMyStreet::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "user_planned_reports",
  "FixMyStreet::DB::Result::UserPlannedReport",
  { "foreign.report_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2017-02-13 15:11:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8zzWlJX7OQOdvrGxKuZUmg

# Add fake relationship to stored procedure table
__PACKAGE__->has_one(
  "nearby",
  "FixMyStreet::DB::Result::Nearby",
  { "foreign.problem_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->might_have(
  "moderation_original_data",
  "FixMyStreet::DB::Result::ModerationOriginalData",
  { "foreign.problem_id" => "self.id" },
  { where => { 'comment_id' => undef },
    cascade_copy => 0, cascade_delete => 1 },
);

__PACKAGE__->load_components("+FixMyStreet::DB::RABXColumn");
__PACKAGE__->rabx_column('extra');
__PACKAGE__->rabx_column('geocode');

use Moo;
use namespace::clean -except => [ 'meta' ];
use Utils;
use FixMyStreet::Map::FMS;
use LWP::Simple qw($ua);
use RABX;
use URI;
use URI::QueryParam;

my $IM = eval {
    require Image::Magick;
    Image::Magick->import;
    1;
};

with 'FixMyStreet::Roles::Abuser',
     'FixMyStreet::Roles::Extra',
     'FixMyStreet::Roles::PhotoSet';

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

    @visible_states = FixMyStreet::DB::Problem::visible_states();
    @hidden_states  = FixMyStreet::DB::Problem::hidden_states();

Get a list of states that should be visible (or hidden) on the site. If called
in array context then returns an array of names, otherwise returns a HASHREF.

=cut

my $hidden_states = {
    'hidden' => 1,
    'partial' => 1,
    'unconfirmed' => 1,
};

my $visible_states = {
    map {
        $hidden_states->{$_} ? () : ($_ => 1)
    } all_states()
};
    ## e.g.:
    # 'confirmed'                   => 1,
    # 'investigating'               => 1,
    # 'in progress'                 => 1,
    # 'planned'                     => 1,
    # 'action scheduled'            => 1,
    # 'fixed'                       => 1,
    # 'fixed - council'             => 1,
    # 'fixed - user'                => 1,
    # 'unable to fix'               => 1,
    # 'not responsible'             => 1,
    # 'duplicate'                   => 1,
    # 'closed'                      => 1,
    # 'internal referral'           => 1,

sub hidden_states {
    return wantarray ? keys %{$hidden_states} : $hidden_states;
}

sub visible_states {
    return wantarray ? keys %{$visible_states} : $visible_states;
}

sub visible_states_add {
    my ($self, @states) = @_;
    for my $state (@states) {
        delete $hidden_states->{$state};
        $visible_states->{$state} = 1;
    }
}

sub visible_states_remove {
    my ($self, @states) = @_;
    for my $state (@states) {
        delete $visible_states->{$state};
        $hidden_states->{$state} = 1;
    }
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

my $stz = sub {
    my ( $orig, $self ) = ( shift, shift );
    my $s = $self->$orig(@_);
    return $s unless $s && UNIVERSAL::isa($s, "DateTime");
    FixMyStreet->set_time_zone($s);
    return $s;
};

around created => $stz;
around confirmed => $stz;
around whensent => $stz;
around lastupdate => $stz;

around service => sub {
    my ( $orig, $self ) = ( shift, shift );
    # service might be undef if e.g. unsaved code report
    my $s = $self->$orig(@_) || "";
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
          && $self->bodies_str =~ m/^(?:-1|[\d,]+)$/;

    if ( !$self->name || $self->name !~ m/\S/ ) {
        $errors{name} = _('Please enter your name');
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
    $self->confirmed( \'current_timestamp' );
    return 1;
}

sub bodies_str_ids {
    my $self = shift;
    return [] unless $self->bodies_str;
    my @bodies = split( /,/, $self->bodies_str );
    return \@bodies;
}

=head2 bodies

Returns a hashref of bodies to which a report was sent.

=cut

sub bodies($) {
    my $self = shift;
    return {} unless $self->bodies_str;
    my $bodies = $self->bodies_str_ids;
    my @bodies = $self->result_source->schema->resultset('Body')->search({ id => $bodies })->all;
    return { map { $_->id => $_ } @bodies };
}

=head2 url

Returns a URL for this problem report.

=cut

sub url {
    my $self = shift;
    return "/report/" . $self->id;
}

sub admin_url {
    my ($self, $cobrand) = @_;
    return $cobrand->admin_base_url . '/report_edit/' . $self->id;
}

=head2 tokenised_url

Return a url for this problem report that logs a user in

=cut

sub tokenised_url {
    my ($self, $user, $params) = @_;

    my $token = FixMyStreet::App->model('DB::Token')->create(
        {
            scope => 'email_sign_in',
            data  => {
                id    => $self->id,
                email => $user->email,
                r     => $self->url,
                p     => $params,
            }
        }
    );

    return "/M/". $token->token;
}

=head2 is_open

Returns 1 if the problem is in a open state otherwise 0.

=cut

sub is_open {
    my $self = shift;

    return exists $self->open_states->{ $self->state } ? 1 : 0;
}

=head2 is_in_progress

Sees if the problem is in an open, not 'confirmed' state.

=cut

sub is_in_progress {
    my $self = shift;
    return $self->is_open && $self->state ne 'confirmed' ? 1 : 0;
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

=head2 state_display

Returns a string suitable for display lookup in the update meta section.
Removes the '- council/user' bit from fixed states.

=cut

sub state_display {
    my $self = shift;
    (my $state = $self->state) =~ s/ -.*$//;
    return $state;
}

=head2 meta_line

Returns a string to be used on a problem report page, describing some of the
meta data about the report.

=cut

sub meta_line {
    my ( $problem, $c ) = @_;

    my $date_time = Utils::prettify_dt( $problem->confirmed );
    my $meta = '';

    my $category = $problem->category;
    $category = $c->cobrand->call_hook(change_category_text => $category) || $category;

    if ( $problem->anonymous ) {
        if ( $problem->service and $category && $category ne _('Other') ) {
            $meta =
            sprintf( _('Reported via %s in the %s category anonymously at %s'),
                $problem->service, $category, $date_time );
        } elsif ( $problem->service ) {
            $meta = sprintf( _('Reported via %s anonymously at %s'),
                $problem->service, $date_time );
        } elsif ( $category and $category ne _('Other') ) {
            $meta = sprintf( _('Reported in the %s category anonymously at %s'),
                $category, $date_time );
        } else {
            $meta = sprintf( _('Reported anonymously at %s'), $date_time );
        }
    } else {
        my $problem_name = $problem->name;

        if ($c->user_exists and
            $c->user->has_permission_to('view_body_contribute_details', $problem->bodies_str_ids) and
            $problem->name ne $problem->user->name) {
            $problem_name = sprintf('%s (%s)', $problem->name, $problem->user->name );
        }

        if ( $problem->service and $category && $category ne _('Other') ) {
            $meta = sprintf(
                _('Reported via %s in the %s category by %s at %s'),
                $problem->service, $category,
                $problem_name,    $date_time
            );
        } elsif ( $problem->service ) {
            $meta = sprintf( _('Reported via %s by %s at %s'),
                $problem->service, $problem_name, $date_time );
        } elsif ( $category and $category ne _('Other') ) {
            $meta = sprintf( _('Reported in the %s category by %s at %s'),
                $category, $problem_name, $date_time );
        } else {
            $meta = sprintf( _('Reported by %s at %s'), $problem_name, $date_time );
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
                if ($c and FixMyStreet->config('AREA_LINKS_FROM_PROBLEMS')) {
                    '<a href="' . $_->url($c) . '">' . $name . '</a>';
                } else {
                    $name;
                }
            } values %$bodies
        );
    }
    return $body;
}


=head2 time_ago
  Returns how long ago a problem was reported in an appropriately
  prettified duration, depending on the duration.
=cut

sub time_ago {
    my ( $self, $date ) = @_;
    $date ||= 'confirmed';
    my $duration = time() - $self->$date->epoch;

    return Utils::prettify_duration( $duration );
}

=head2 days_ago

  Returns how many days ago a problem was reported.

=cut

sub days_ago {
    my ( $self, $date ) = @_;
    $date ||= 'confirmed';
    my $now = DateTime->now( time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone );
    my $duration = $now->delta_days($self->$date);
    return $duration->delta_days;
}

=head2 response_templates

Returns all ResponseTemplates attached to this problem's bodies, in alphabetical
order of title.

=cut

sub response_templates {
    my $self = shift;
    return $self->result_source->schema->resultset('ResponseTemplate')->search(
        {
            'me.body_id' => $self->bodies_str_ids,
            'contact.category' => [ $self->category, undef ],
        },
        {
            order_by => 'title',
            join => { 'contact_response_templates' => 'contact' },
        }
    );
}

=head2 response_priorities

Returns all ResponsePriorities attached to this problem's category/contact, in
alphabetical order of name.

=cut

sub response_priorities {
    my $self = shift;
    return $self->result_source->schema->resultset('ResponsePriority')->for_bodies($self->bodies_str_ids, $self->category);
}

=head2 defect_types

Returns all DefectTypes attached to this problem's category/contact, in
alphabetical order of name.

=cut

sub defect_types {
    my $self = shift;
    return $self->result_source->schema->resultset('DefectType')->for_bodies($self->bodies_str_ids, $self->category);
}

# returns true if the external id is the council's ref, i.e., useful to publish it
# (by way of an example, the Oxfordshire send method returns a useful reference when
# it succeeds, so that is the ref we should show on the problem report page).
#     Future: this is installation-dependent so maybe should be using the contact
#             data to determine if the external id is public on a council-by-council basis.
#     Note:   this only makes sense when called on a problem that has been sent!
sub can_display_external_id {
    my $self = shift;
    if ($self->external_id && $self->send_method_used && $self->bodies_str =~ /(2237|2550)/) {
        return 1;
    }
    return 0;
}

sub duration_string {
    my ( $problem, $c ) = @_;
    my $body = $c->cobrand->call_hook(link_to_council_cobrand => $problem) || $problem->body($c);
    my $handler = $c->cobrand->call_hook(get_body_handler_for_problem => $problem);
    if ( $handler && $handler->call_hook('is_council_with_case_management') ) {
        return sprintf(_('Received by %s moments later'), $body);
    }
    return unless $problem->whensent;
    return sprintf(_('Sent to %s %s later'), $body,
        Utils::prettify_duration($problem->whensent->epoch - $problem->confirmed->epoch, 'minute')
    );
}

sub local_coords {
    my $self = shift;
    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($self->cobrand)->new;
    if ($cobrand->moniker eq 'zurich') {
        my ($x, $y) = Geo::Coordinates::CH1903Plus::from_latlon($self->latitude, $self->longitude);
        return ( int($x+0.5), int($y+0.5) );
    } elsif ($cobrand->country eq 'GB') {
        my $coordsyst = 'G';
        $coordsyst = 'I' if FixMyStreet::Map::FMS::in_northern_ireland_box($self->latitude, $self->longitude);
        my ($x, $y) = Utils::convert_latlon_to_en( $self->latitude, $self->longitude, $coordsyst );
        return ($x, $y, $coordsyst);
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

    my $update = $self->new_related(comments => {
        state => 'confirmed',
        created => $updated || \'current_timestamp',
        confirmed => \'current_timestamp',
        text => $status_notes,
        mark_open => 0,
        mark_fixed => 0,
        user => $system_user,
        anonymous => 0,
        name => $body->name,
    });

    my $w3c = DateTime::Format::W3CDTF->new;
    my $req_time = $w3c->parse_datetime( $request->{updated_datetime} );

    # set a timezone here as the $req_time will have one and if we don't
    # use a timezone then the date comparisons are invalid.
    # of course if local timezone is not the one that went into the data
    # base then we're also in trouble
    my $lastupdate = $self->lastupdate;
    $lastupdate->set_time_zone( FixMyStreet->local_time_zone );

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
        send_fail_timestamp => \'current_timestamp',
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
        photos    => [ map { $_->{url} } @{$self->photos} ],
        meta      => $self->confirmed ? $self->meta_line( $c ) : '',
        confirmed_pp => $self->confirmed ? $c->cobrand->prettify_dt( $self->confirmed ): '',
        created_pp => $c->cobrand->prettify_dt( $self->created ),
    };
}

=head2 latest_moderation_log_entry

Return most recent ModerationLog object

=cut

sub latest_moderation_log_entry {
    my $self = shift;
    return $self->admin_log_entries->search({ action => 'moderation' }, { order_by => { -desc => 'id' } })->first;
}

sub photos {
    my $self = shift;
    my $photoset = $self->get_photoset;
    my $i = 0;
    my $id = $self->id;
    my @photos = map {
        my $cachebust = substr($_, 0, 8);
        my ($hash, $format) = split /\./, $_;
        {
            id => $hash,
            url_temp => "/photo/temp.$hash.$format",
            url_temp_full => "/photo/fulltemp.$hash.$format",
            url => "/photo/$id.$i.$format?$cachebust",
            url_full => "/photo/$id.$i.full.$format?$cachebust",
            url_tn => "/photo/$id.$i.tn.$format?$cachebust",
            url_fp => "/photo/$id.$i.fp.$format?$cachebust",
            idx => $i++,
        }
    } $photoset->all_ids;
    return \@photos;
}

__PACKAGE__->has_many(
  "admin_log_entries",
  "FixMyStreet::DB::Result::AdminLog",
  { "foreign.object_id" => "self.id" },
  {
      cascade_copy => 0, cascade_delete => 0,
      where => { 'object_type' => 'problem' },
  }
);

sub get_time_spent {
    my $self = shift;
    my $admin_logs = $self->admin_log_entries->search({},
        {
            group_by => 'object_id',
            columns => [
                { sum_time_spent => { sum => 'time_spent' } },
            ]
        })->single;
    return $admin_logs ? $admin_logs->get_column('sum_time_spent') : 0;
}

=head2 get_cobrand_logged

Get a cobrand object for the cobrand the problem was logged for.

e.g. if a problem was logged at www.fixmystreet.com, this will be a
FixMyStreet::Cobrand::FixMyStreet object.

=cut

has get_cobrand_logged => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $cobrand_class = FixMyStreet::Cobrand->get_class_for_moniker( $self->cobrand );
        return $cobrand_class->new;
    },
);


sub pin_data {
    my ($self, $c, $page, %opts) = @_;
    my $colour = $c->cobrand->pin_colour($self, $page);

    {
        latitude => $self->latitude,
        longitude => $self->longitude,
        colour => $colour,
        id => $self->id,
        title => $opts{private} ? $self->title : $self->title_safe,
        problem => $self,
        type => $opts{type},
    }
};

sub static_map {
    my ($self) = @_;

    return unless $IM;

    my $orig_map_class = FixMyStreet::Map::set_map_class('OSM')
        unless $FixMyStreet::Map::map_class->isa("FixMyStreet::Map::OSM");

    my $map_data = $FixMyStreet::Map::map_class->generate_map_data(
        { cobrand => $self->get_cobrand_logged },
        latitude  => $self->latitude,
        longitude => $self->longitude,
        pins      => $self->used_map
        ? [ {
            latitude  => $self->latitude,
            longitude => $self->longitude,
            colour    => $self->get_cobrand_logged->pin_colour($self, 'report'),
            type      => 'big',
          } ]
        : [],
    );

    $ua->agent("FixMyStreet/1.0");
    my $image;
    for (my $i=0; $i<4; $i++) {
        my $tile_url = $map_data->{tiles}->[$i];
        if ($tile_url =~ m{^//}) {
            $tile_url = "https:$tile_url";
        }
        my $tile;
        if (FixMyStreet->test_mode) {
            $tile = FixMyStreet->path_to('t/app/controller/sample.jpg')->slurp(iomode => '<:raw');
        } else {
            $tile = LWP::Simple::get($tile_url);
        }
        next unless $tile;
        my $im = Image::Magick->new;
        $im->BlobToImage($tile);
        my $gravity = ($i<2?'North':'South') . ($i%2?'East':'West');
        if (!$image) {
            $image = $im;
            $image->Extent(geometry => '512x512', gravity => $gravity);
        } else {
            $image->Composite(image => $im, gravity => $gravity);
        }
    }

    unless ($image) {
        FixMyStreet::Map::set_map_class($orig_map_class) if $orig_map_class;
        return;
    }

    # The only pin might be the report pin, with added x/y
    my $pin = $map_data->{pins}->[0];
    if ($pin) {
        my $im = Image::Magick->new;
        $im->read(FixMyStreet->path_to('web', 'i', 'pin-yellow.png'));
        $image->Composite(image => $im, gravity => 'NorthWest',
            x => $pin->{px} - 24, y => $pin->{py} - 64);
    }

    # Bottom 128/ top 64 pixels will never have a pin
    $image->Extent( geometry => '512x384', gravity => 'NorthWest');
    $image->Extent( geometry => '512x320', gravity => 'SouthWest');

    $image->Scale( geometry => "310x200>" );

    my @blobs = $image->ImageToBlob(magick => 'jpeg');
    undef $image;

    FixMyStreet::Map::set_map_class($orig_map_class) if $orig_map_class;

    return {
        data => $blobs[0],
        content_type => 'image/jpeg',
    };
}

has shortlisted_user => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $user = $self->user_planned_reports->active->first;
        return $user->user if $user;
    },
);

has duplicate_of => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        return unless $self->state eq 'duplicate';
        my $duplicate_of = int($self->get_extra_metadata("duplicate_of") || 0);
        return unless $duplicate_of;
        return $self->result_source->schema->resultset('Problem')->search({ id => $duplicate_of })->first;
    },
);

has duplicates => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $rabx_id = RABX::serialise( $self->id );
        my @duplicates = $self->result_source->schema->resultset('Problem')->search({ extra => { like => "\%duplicate_of,$rabx_id%" } })->all;
        return \@duplicates;
    },
);

has traffic_management_options => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $cobrand = $self->get_cobrand_logged;
        $cobrand = $cobrand->call_hook(get_body_handler_for_problem => $self) || $cobrand;
        return $cobrand->traffic_management_options;
    },
);

has inspection_log_entry => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->admin_log_entries->search({ action => 'inspected' }, { order_by => { -desc => 'whenedited' } })->first;
    },
);

1;
