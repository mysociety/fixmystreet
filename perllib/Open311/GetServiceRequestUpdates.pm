package Open311::GetServiceRequestUpdates;

use Moo;
use Open311;
use Parallel::ForkManager;
use FixMyStreet::DB;
use FixMyStreet::App::Model::PhotoSet;
use DateTime::Format::W3CDTF;

has system_user => ( is => 'rw' );
has start_date => ( is => 'ro', default => sub { undef } );
has end_date => ( is => 'ro', default => sub { undef } );
has body => ( is => 'ro', default => sub { undef } );
has suppress_alerts => ( is => 'rw', default => 0 );
has verbose => ( is => 'ro', default => 0 );
has schema => ( is =>'ro', lazy => 1, default => sub { FixMyStreet::DB->schema->connect } );
has blank_updates_permitted => ( is => 'rw', default => 0 );

has current_body => ( is => 'rw' );
has current_open311 => ( is => 'rw' );

Readonly::Scalar my $AREA_ID_BROMLEY     => 2482;
Readonly::Scalar my $AREA_ID_OXFORDSHIRE => 2237;

sub fetch {
    my ($self, $open311) = @_;

    my $bodies = $self->schema->resultset('Body')->search(
        {
            send_method     => 'Open311',
            send_comments   => 1,
            comment_user_id => { '!=', undef },
            endpoint        => { '!=', '' },
        }
    );

    if ( $self->body ) {
        $bodies = $bodies->search( { name => $self->body } );
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

        $self->current_body( $body );

        my %open311_conf = (
            endpoint => $body->endpoint,
            api_key => $body->api_key,
            jurisdiction => $body->jurisdiction,
            extended_statuses => $body->send_extended_statuses,
        );

        my $cobrand = $body->get_cobrand_handler;
        $cobrand->call_hook(open311_config_updates => \%open311_conf)
            if $cobrand;

        $self->current_open311( $open311 || Open311->new(%open311_conf) );

        $self->suppress_alerts( $body->suppress_alerts );
        $self->blank_updates_permitted( $body->blank_updates_permitted );
        $self->system_user( $body->comment_user );
        $self->process_body();

        $pm->finish;
    }

    $pm->wait_all_children;
}

sub parse_dates {
    my $self = shift;
    my $body = $self->current_body;

    my @args = ();

    my $dt = DateTime->now();
    # Oxfordshire uses local time and not UTC for dates
    FixMyStreet->set_time_zone($dt) if $body->areas->{$AREA_ID_OXFORDSHIRE};

    # default to asking for last 2 hours worth if not Bromley
    if ($self->start_date) {
        push @args, DateTime::Format::W3CDTF->format_datetime( $self->start_date );
    } elsif ( ! $body->areas->{$AREA_ID_BROMLEY} ) {
        my $start_dt = $dt->clone->add( hours => -2 );
        push @args, DateTime::Format::W3CDTF->format_datetime( $start_dt );
    }

    if ($self->end_date) {
        push @args, DateTime::Format::W3CDTF->format_datetime( $self->end_date );
    } elsif ( ! $body->areas->{$AREA_ID_BROMLEY} ) {
        push @args, DateTime::Format::W3CDTF->format_datetime( $dt );
    }

    return @args;
}

sub process_body {
    my $self = shift;

    my $open311 = $self->current_open311;
    my $body = $self->current_body;
    my @args = $self->parse_dates;
    my $requests = $open311->get_service_request_updates( @args );

    unless ( $open311->success ) {
        warn "Failed to fetch ServiceRequest Updates for " . $body->name . ":\n" . $open311->error
            if $self->verbose;
        return 0;
    }

    for my $request (@$requests) {
        next unless defined $request->{update_id};

        my $p = $self->find_problem($request, @args) or next;
        my $c = $p->comments->search( { external_id => $request->{update_id} } );
        next if $c->first;

        $self->process_update($request, $p);
    }

    return 1;
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

    my $body = $self->current_body;
    my $request_id = $request->{service_request_id};

    # If there's no request id then we can't work out
    # what problem it belongs to so just skip
    return unless $request_id || $request->{fixmystreet_id};

    my $problem;
    my $criteria = {
        external_id => $request_id,
    };

    # in some cases we only have the FMS id and not the request id so use that
    if ( $request->{fixmystreet_id} ) {
        unless ( $request->{fixmystreet_id} =~ /^\d+$/ ) {
            warn "skipping bad fixmystreet id in updates for " . $body->name . ": [" . $request->{fixmystreet_id} . "], external id is $request_id\n";
            return;
        }

        $criteria = {
            id => $request->{fixmystreet_id},
        };
    }

    $problem = $self->schema->resultset('Problem')->to_body($body)->search( $criteria );
    return $problem->first;
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
    my $comment = $self->schema->resultset('Comment')->new(
        {
            problem => $p,
            user => $self->system_user,
            external_id => $request->{update_id},
            text => $self->comment_text_for_request(
                $request, $p, $state, $old_state,
                $external_status_code, $old_external_status_code
            ),
            mark_fixed => 0,
            mark_open => 0,
            anonymous => 0,
            name => $self->system_user->name,
            confirmed => $request->{comment_time},
            created => $request->{comment_time},
            state => 'confirmed',
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
            ( $comment->created >= $p->lastupdate || $p->comments->count == 0 ) ) {
            $p->state($state);
        }
    }

    # If nothing to show (no text, photo, or state change), don't show this update
    $comment->state('hidden') unless $comment->text || $comment->photo
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
    $p->update;
    $comment->insert();

    if ( $self->suppress_alerts ) {
        my @alerts = $self->schema->resultset('Alert')->search( {
            alert_type => 'new_updates',
            parameter  => $p->id,
            confirmed  => 1,
            user_id    => $p->user->id,
        } );

        for my $alert (@alerts) {
            my $alerts_sent = $self->schema->resultset('AlertSent')->find_or_create( {
                alert_id  => $alert->id,
                parameter => $comment->id,
            } );
        }
    }

    return $comment;
}

sub comment_text_for_request {
    my ($self, $request, $problem, $state, $old_state,
        $ext_code, $old_ext_code) = @_;

    # Response templates are only triggered if the state/external status has changed.
    # And treat any fixed state as fixed.
    my $state_changed = $state ne $old_state
        && !( $problem->is_fixed && FixMyStreet::DB::Result::Problem->fixed_states()->{$state} );
    my $ext_code_changed = $ext_code ne $old_ext_code;
    my $template;
    if ($state_changed || $ext_code_changed) {
        my $order;
        my $state_params = {
            'me.state' => $state
        };
        if ($ext_code) {
            $state_params->{'me.external_status_code'} = $ext_code;
            # make sure that empty string/nulls come last.
            $order = { order_by => \"me.external_status_code DESC NULLS LAST" };
        };

        if (my $t = $problem->response_templates->search({
            auto_response => 1,
            -or => $state_params,
        }, $order )->first) {
            $template = $t->text;
        }
    }

    my $desc = $request->{description} || '';
    if ($desc && (!$template || $template !~ /\{\{description}}/)) {
        return $desc;
    }

    if ($template) {
        $template =~ s/\{\{description}}/$desc/;
        return $template;
    }

    return "" if $self->blank_updates_permitted;

    print STDERR "Couldn't determine update text for $request->{update_id} (report " . $problem->id . ")\n";
    return "";
}

1;
