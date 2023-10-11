package Open311::UpdatesBase;

use Moo;
use Open311;
use Parallel::ForkManager;
use FixMyStreet::DB;

has send_comments_flag => ( is => 'ro' );

# Default is yes, as this has previously been assumed
has commit => ( is => 'ro', default => 1 );

has system_user => ( is => 'rw' );
has bodies => ( is => 'ro', default => sub { [] } );
has bodies_exclude => ( is => 'ro', default => sub { [] } );
has verbose => ( is => 'ro', default => 0 );
has schema => ( is =>'ro', lazy => 1, default => sub { FixMyStreet::DB->schema->connect } );
has suppress_alerts => ( is => 'rw', default => 0 );
has blank_updates_permitted => ( is => 'rw', default => 0 );

has current_body => ( is => 'rw' );
has current_open311 => ( is => 'rwp', lazy => 1, builder => 1 );
has open311_config => ( is => 'ro' ); # If we need to pass in a devolved contact

Readonly::Scalar my $AREA_ID_OXFORDSHIRE => 2237;

sub fetch {
    my ($self, $open311) = @_;

    my $bodies = $self->schema->resultset('Body')->search(
        {
            send_method     => 'Open311',
            send_comments   => $self->send_comments_flag,
            comment_user_id => { '!=', undef },
            endpoint        => { '!=', '' },
        }
    );

    if ( @{$self->bodies} ) {
        $bodies = $bodies->search( { name => $self->bodies } );
    }
    if ( @{$self->bodies_exclude} ) {
        $bodies = $bodies->search( { name => { -not_in => $self->bodies_exclude } } );
    }

    my $procs_min = FixMyStreet->config('FETCH_COMMENTS_PROCESSES_MIN') || 0;
    my $procs_max = FixMyStreet->config('FETCH_COMMENTS_PROCESSES_MAX');
    my $procs_timeout = FixMyStreet->config('FETCH_COMMENTS_PROCESS_TIMEOUT');

    my $pm = Parallel::ForkManager->new(FixMyStreet->test_mode ? 0 : $procs_min);

    if ($procs_max && $procs_timeout) {
        my %workers;
        $pm->run_on_wait(sub {
            while (my ($pid, $started_at) = each %workers) {
                next unless time() - $started_at > $procs_timeout;
                next if $pm->max_procs == $procs_max;
                $pm->set_max_procs($pm->max_procs + 1);
                delete $workers{$pid}; # Only want to increase once per long-running thing
            }
        }, 1);
        $pm->run_on_start(sub { my $pid = shift; $workers{$pid} = time(); });
        $pm->run_on_finish(sub { my $pid = shift; delete $workers{$pid}; });
    }

    while ( my $body = $bodies->next ) {
        $pm->start and next;

        $self->initialise_body( $body );
        $self->_set_current_open311( $open311 || $self->_build_current_open311 );
        $self->process_body();

        $pm->finish;
    }

    $pm->wait_all_children;
}

sub initialise_body {
    my ($self, $body) = @_;

    $self->current_body( $body );
    $self->suppress_alerts( $body->suppress_alerts );
    $self->blank_updates_permitted( $body->blank_updates_permitted );
    $self->system_user( $body->comment_user );
}

sub _build_current_open311 {
    my $self = shift;

    my $body = $self->current_body;
    my $conf = $self->open311_config || $body;
    my %open311_conf = (
        endpoint => $conf->endpoint || '',
        api_key => $conf->api_key || '',
        jurisdiction => $conf->jurisdiction || '',
        extended_statuses => $body->send_extended_statuses,
    );

    my $cobrand = $body->get_cobrand_handler;
    $cobrand->call_hook(open311_config_updates => \%open311_conf)
        if $cobrand;

    return Open311->new(%open311_conf);
}

sub check_date {
    my ($self, $request, @args) = @_;

    my $comment_time = eval {
        DateTime::Format::W3CDTF->parse_datetime( $request->{updated_datetime} || "" )
            ->set_time_zone(FixMyStreet->local_time_zone);
    };
    return if $@;
    my $updated = DateTime::Format::W3CDTF->format_datetime($comment_time->clone->set_time_zone('UTC'));
    return if @args && ($updated lt $args[0] || $updated gt $args[1]);
    $request->{comment_time} = $comment_time;
    return 1;
}

sub find_problem {
    my ($self, $request, @args) = @_;

    $self->check_date($request, @args) or return;

    my $request_id = $request->{service_request_id};

    # If there's no request id then we can't work out
    # what problem it belongs to so just skip
    return unless $request_id || $request->{fixmystreet_id};

    my $criteria = {
        external_id => $request_id,
    };

    # in some cases we only have the FMS id and not the request id so use that
    if ( $request->{fixmystreet_id} ) {
        unless ( $request->{fixmystreet_id} =~ /^\d+$/ ) {
            warn "skipping bad fixmystreet id in updates for " . $self->current_body->name . ": [" . $request->{fixmystreet_id} . "], external id is $request_id\n";
            return;
        }

        $criteria = {
            id => $request->{fixmystreet_id},
        };
    }

    return $self->_find_problem($criteria);
}

sub process_update {
    my ($self, $request, $p) = @_;

    my $open311 = $self->current_open311;
    my $body = $self->current_body;

    my $state = $open311->map_state( $request->{status} );
    my $old_state = $p->state;
    my $external_status_code = $request->{external_status_code} || '';
    my $customer_reference = $request->{customer_reference} || '';
    my $old_external_status_code = $p->get_extra_metadata('external_status_code') || '';
    my $template = $p->response_template_for(
        $state, $old_state, $external_status_code, $old_external_status_code
    );
    my ($text, $email_text) = $self->comment_text_for_request($template, $request, $p);
    if (!$email_text && $request->{email_text}) {
        $email_text = $request->{email_text};
    };

    # An update shouldn't precede an auto-internal update nor should it be earlier than when the
    # report was sent.
    my $auto_comment = $p->comments->search({ external_id => 'auto-internal' })->first;
    if ($auto_comment) {
        if ($request->{comment_time} <= $auto_comment->confirmed) {
            $request->{comment_time} = $auto_comment->confirmed + DateTime::Duration->new( seconds => 1 );
        }
    } elsif ($p->whensent && $request->{comment_time} <= $p->whensent) {
        $request->{comment_time} = $p->whensent + DateTime::Duration->new( seconds => 1 );
    }

    my $comment = $self->schema->resultset('Comment')->new(
        {
            problem => $p,
            user => $self->system_user,
            external_id => $request->{update_id},
            send_state => 'processed',
            text => $text,
            confirmed => $request->{comment_time},
            created => $request->{comment_time},
            private_email_text => $email_text,
        }
    );

    # Some Open311 services, e.g. Confirm via open311-adapter, provide
    # a more fine-grained status code that we use within FMS for
    # response templates.
    if ( $external_status_code ) {
        $comment->set_extra_metadata(external_status_code => $external_status_code);
        $p->set_extra_metadata(external_status_code => $external_status_code);
    } else {
        $p->set_extra_metadata(external_status_code => '');
    }

    # if the customer reference to display in the report metadata is
    # not the same as the external_id
    if ( $customer_reference ) {
        $p->set_extra_metadata( customer_reference => $customer_reference );
    }

    $open311->add_media($request->{media_url}, $comment)
        if $request->{media_url};

    # don't update state unless it's an allowed state
    if ( FixMyStreet::DB::Result::Problem->visible_states()->{$state} &&
        # For Oxfordshire, don't allow changes back to Open from other open states
        !( $body->areas->{$AREA_ID_OXFORDSHIRE} && $state eq 'confirmed' && $p->is_open ) &&
        # Don't let it change between the (same in the front end) fixed states
        !( $p->is_fixed && FixMyStreet::DB::Result::Problem->fixed_states()->{$state} ) ) {

        $comment->problem_state($state);

        # we only want to update the problem state if that makes sense. We never want to unhide a problem.
        # If the update is older than the last update then we also do not want to update the state. This
        # is largely to avoid the situation where we miss some updates, make more updates and then catch
        # the updates when we fetch the last 24 hours of updates. The exception to this is the first
        # comment. This is to catch automated updates which happen faster than we get the external_id
        # back from the endpoint and hence have an created time before the lastupdate.
        if ( $p->is_visible && $p->state ne $state &&
            ( $comment->created >= $p->lastupdate || $p->comments->count == 0 || ($p->comments->count == 1 && $p->comments->first->external_id eq "auto-internal") )) {
            $p->state($state);
        }
    }

    # Hide if the new comment is the same as the latest comment
    my $latest = $comment->problem->comments->search({ state => 'confirmed' }, {
        order_by => [ { -desc => 'confirmed' }, { -desc => 'id' } ],
        rows => 1,
    })->first;
    $latest = undef if $latest && $latest->user_id != $comment->user_id;

    # If nothing to show (no text change, photo, or state change), don't show this update
    $comment->state('hidden') unless
        $comment->text && (!$latest || $latest->text ne $comment->text)
        || $comment->photo
        || ($comment->problem_state && $state ne $old_state);

    my $cobrand = $body->get_cobrand_handler;
    $cobrand->call_hook(open311_get_update_munging => $comment)
        if $cobrand;

    # As comment->created has been looked at above, its time zone has been shifted
    # to TIME_ZONE (if set). We therefore need to set it back to local before
    # insertion. We also then need a clone, otherwise the setting of lastupdate
    # will *also* reshift comment->created's time zone to TIME_ZONE.
    my $created = $comment->created->set_time_zone(FixMyStreet->local_time_zone);
    $p->lastupdate($created->clone);

    return $comment unless $self->commit;

    $p->update;
    $comment->insert();

    if ( $self->suppress_alerts ) {
        $p->cancel_update_alert($comment->id, $p->user->id);
    }

    return $comment;
}

sub comment_text_for_request {
    my ($self, $template, $request, $problem) = @_;

    my $template_email_text = $template->email_text if $template;
    $template = $template->text if $template;

    my $desc = $request->{description} || '';
    if ($desc && (!$template || ($template !~ /\{\{description}}/ && !$request->{prefer_template}))) {
        return ($desc, undef);
    }

    if ($template) {
        $template =~ s/\{\{description}}/$desc/;
        return ($template, $template_email_text);
    }

    return ("", undef) if $self->blank_updates_permitted;

    print STDERR "Couldn't determine update text for $request->{update_id} (report " . $problem->id . ")\n";
    return ("", undef);
}

1;
