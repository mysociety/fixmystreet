package FixMyStreet::Roles::ParallelAPI;
use Moo::Role;
use JSON::MaybeXS;
use Parallel::ForkManager;
use Storable qw(retrieve_fd retrieve);
use Time::HiRes;
use Digest::MD5 qw(md5_hex);
use Try::Tiny;
use Fcntl qw(:flock);

# ---
# Calling things in parallel

sub call_api {
    # Shifting because the remainder of @_ is passed along further down
    my ($self, $c, $cobrand, $key, $fork) = (shift, shift, shift, shift, shift);

    my $type = $self->backend_type;
    $key = "$cobrand:$type:$key";
    return $c->session->{$key} if !FixMyStreet->test_mode && $c->session->{$key};

    my $calls = encode_json(\@_);

    my $outdir = FixMyStreet->config('WASTEWORKS_BACKEND_TMP_DIR');
    mkdir($outdir) unless -d $outdir;
    my $tmp = $outdir . "/" . md5_hex("$key $calls");

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
    # uncoverable branch false
    if (FixMyStreet->test_mode || $self->sample_data) {
        $data = $self->_parallel_api_calls(@_);
    } elsif (-e $tmp) {
        # if output file is already there, we can only open it if it's finished with
        try {
            open(my $fd, "<", $tmp) or die;
            flock($fd, LOCK_SH|LOCK_NB) or die;
            $data = retrieve_fd($fd);
            flock($fd, LOCK_UN);
            close($fd);
            unlink $tmp; # don't want to inadvertently cache forever
        };
    } else {
        if ($fork) {
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
        $c->session->{$key} = $data;
        my $time = Time::HiRes::time() - $start;
        $c->log->info("[$cobrand] call_api $key took $time seconds");
    }
    return $data;
}

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
