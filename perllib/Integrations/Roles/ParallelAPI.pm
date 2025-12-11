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
use Storable qw(retrieve_fd retrieve);
use Time::HiRes;
use Digest::MD5 qw(md5_hex);
use Try::Tiny;
use Fcntl qw(:flock);

=head2 call_api

  call_api($c, "bromley", "look_up_property:123", 0,
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
    my ($self, $c, $cobrand, $key, $background) = (shift, shift, shift, shift, shift);

    my $type = $self->backend_type;
    $key = "$cobrand:$type:$key";
    if (!FixMyStreet->test_mode) {
        my $cached = $c->waste_cache_get($key);
        return $cached if $cached;
    }

    my $calls = encode_json(\@_);

    my $outdir = FixMyStreet->config('WASTEWORKS_BACKEND_TMP_DIR');
    mkdir($outdir) unless -d $outdir;
    my $tmp = $outdir . "/" . md5_hex("$key $calls");
    if (-e $tmp && _uncleared_file($tmp)) {
        unlink($tmp);
    }

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
    if ((FixMyStreet->test_mode || $self->sample_data) && $self->sample_data != 2) {
        $start_call = 0;
        $data = $self->_parallel_api_calls(@_);
    } elsif (-e $tmp) {
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
                unlink $tmp; # don't want to inadvertently cache forever
            };
        };
    }

    # Either the temp file wasn't there, or it had bad data
    if ($start_call) {
        if ($self->sample_data == 2) {
            $data = $self->_parallel_api_calls(@_);
        } elsif ($background) {
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
            unlink $tmp; # don't want to inadvertently cache forever
        }
    }

    if ($data) {
        $c->waste_cache_set($key, $data);
        my $time = Time::HiRes::time() - $start;
        $c->log->info("[$cobrand] call_api $key took $time seconds");
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

=head2 _uncleared_file

Return a positive if a file is over a minute old

=cut

sub _uncleared_file {
    my $file = shift;

    my $time = time;
    my @stat = stat($file);

    if (($time - $stat[9]) > 60) {
        return 1;
    }
}

1;
