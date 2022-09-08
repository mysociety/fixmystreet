package FixMyStreet::Roles::ParallelAPI;
use Moo::Role;
use JSON::MaybeXS;
use Parallel::ForkManager;
use Storable;
use Time::HiRes;

# ---
# Calling things in parallel

sub call_api {
    # Shifting because the remainder of @_ is passed along further down
    my ($self, $c, $cobrand, $key) = (shift, shift, shift, shift);

    my $type = $self->backend_type;
    $key = "$cobrand:$type:$key";
    return $c->session->{$key} if !FixMyStreet->test_mode && $c->session->{$key};

    my $tmp = File::Temp->new;
    my @cmd = (
        FixMyStreet->path_to('bin/fixmystreet.com/call-wasteworks-backend'),
        '--cobrand', $cobrand,
        '--backend', $type,
        '--out', $tmp,
        '--calls', encode_json(\@_),
    );
    my $start = Time::HiRes::time();

    # We cannot fork directly under mod_fcgid, so
    # call an external script that calls back in.
    my $data;
    # uncoverable branch false
    if (FixMyStreet->test_mode || $self->sample_data) {
        $data = $self->_parallel_api_calls(@_);
    } else {
        # uncoverable statement
        system(@cmd);
        $data = Storable::fd_retrieve($tmp);
    }
    $c->session->{$key} = $data;
    my $time = Time::HiRes::time() - $start;
    $c->log->info("[$cobrand] call_api $key took $time seconds");
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
