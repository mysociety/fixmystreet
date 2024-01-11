=head1 NAME

Integrations::Roles::ParallelAPI - code for calling external APIs in parallel

=head1 SYNOPSIS

To improve performance, we can sometimes make multiple external API calls in
parallel - this is complicated by forking not being available, so this code
sorts it all out. It can either wait for the results or run the request in the
background (relying on the parent to deal with 'please wait' pages).

=head1 DESCRIPTION

=cut

package Integrations::Roles::ParallelAPI;
use Moo::Role;
use JSON::MaybeXS;
use Parallel::ForkManager;
use Path::Tiny;
use Storable qw(retrieve_fd retrieve);
use Time::HiRes;
use Try::Tiny;
use Fcntl qw(:flock);

=head2 api_cache_for

Set to the amount of time a cached file on disc will
be used to serve a matching API request.

=cut

has api_cache_for => ( is => 'ro', default => 3600 );

=head2 call_api

  call_api($c, "bromley", 123, "look_up_property", 0,
    GetPointAddress => [ 123 ],
    GetServiceUnitsForObject => [ 123 ],
  )

Called with a Catalyst object, a cobrand moniker, a key for the batch (for
caching), whether the call should be backgrounded or not, and then a list of
calls to be made (as methods on the integration object) and their arguments as
an array ref.

It returns either the data (if not sent to background, or if the data is now
available) or detaches immediately to show the current template (which should
have a please loading message and auto-reload).

=cut

sub call_api {
    # Shifting because the remainder of @_ is passed along further down
    my ($self, $c, $cobrand, $property_id, $key, $background) = (shift, shift, shift, shift, shift, shift);

    my $type = $self->backend_type;
    my $calls = encode_json(\@_);

    my $outdir = path(FixMyStreet->config('WASTEWORKS_BACKEND_TMP_DIR'));
    foreach ($cobrand, $property_id) {
        $outdir = $outdir->child($_);
    }

    my $tmp = $outdir->mkdir->child($key);

    my @cmd = (
        FixMyStreet->path_to('bin/fixmystreet.com/call-wasteworks-backend'),
        '--cobrand', $cobrand,
        '--backend', $type,
        '--out', $tmp,
        '--calls', $calls,
    );
    my $start = Time::HiRes::time();

    # We cannot fork directly under mod_fcgid, so
    # call an external script that calls back in.
    my $data;
    my $start_call = 1;

    # uncoverable branch false
    if (FixMyStreet->test_mode || $self->sample_data) {
        $start_call = 0;
        $data = $self->_parallel_api_calls(@_);
    } elsif (-e $tmp && time-(stat($tmp))[9] < $self->api_cache_for) {
        $start_call = 0;
        # if output file is already there, we can only open it if it's finished with
        try {
            open(my $fd, "<", $tmp) or die;
            flock($fd, LOCK_SH|LOCK_NB) or die;
            try {
                $data = retrieve_fd($fd);
            } catch {
                $start_call = 1;
            } finally {
                flock($fd, LOCK_UN);
                close($fd);
            };
        };
    }

    # Either the temp file wasn't there, or it was old or had bad data
    if ($start_call) {
        if ($background) {
            # wrap the $calls value in single quotes
            push(@cmd, "'" . pop(@cmd) . "'");
            # run it in the background
            push @cmd, '&';
            my $cmd = join(" ", @cmd);
            system($cmd);
        } else {
            # uncoverable statement
            system(@cmd);
            $data = retrieve($tmp);
        }
    }

    if ($data) {
        my $time = Time::HiRes::time() - $start;
        $c->log->info("[$cobrand] call_api $property_id $key took $time seconds");
    } elsif ($background) {
        # Bail out here to show loading page
        $c->stash->{template} = 'waste/async_loading.html';
        $c->stash->{data_loading} = 1;
        $c->stash->{page_refresh} = 2;
        $c->detach;
    }
    return $data;
}

=head2 _parallel_api_calls

This uses L<Parallel::ForkManager> to actually fork and make the requested API
calls. Called either directly (if running in tests) or from the external script
called by call_api.

=cut

sub _parallel_api_calls {
    my $self = shift;

    my %calls;
    # uncoverable branch false
    my $pm = Parallel::ForkManager->new(FixMyStreet->test_mode || $self->sample_data ? 0 : 10);
    $pm->run_on_finish(sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
        %calls = ( %calls, %$data );
    });

    while (@_) {
        my $call = shift;
        my $args = shift;
        $pm->start and next;
        my $result = $self->$call(@$args);
        my $key = "$call @$args";
        $key = $call if ( $call eq 'GetTasks' && $self->backend_type eq 'echo' );
        $pm->finish(0, { $key => $result });
    }
    $pm->wait_all_children;

    return \%calls;
}

1;
