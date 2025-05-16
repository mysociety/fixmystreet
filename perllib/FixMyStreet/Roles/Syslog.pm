package FixMyStreet::Roles::Syslog;
use Moo::Role;

use Data::Dumper;
use Sys::Syslog;

# We do force the connection to be a unix socket, because one side effect is we
# can set the ident per-call, unlike with native handling.
Sys::Syslog::setlogsock('unix');

# Syslog has a global ident, which we use to send to different outputs, so we
# call openlog on each log to make sure the ident is the correct one. We are
# not using `ndelay`, so only one connection should be made, at the first log.
sub log {
    my ($self, $str) = @_;
    $str = Dumper($str) if ref $str;

    my $ident = $self->log_ident or return;
    my $opts = '';
    my $facility = 'local6';
    openlog($ident, $opts, $facility);

    syslog('debug', '%s', $str);
}

1;
