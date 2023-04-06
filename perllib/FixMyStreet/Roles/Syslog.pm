package FixMyStreet::Roles::Syslog;
use Moo::Role;

use Data::Dumper;
use Sys::Syslog;

has log_open => (
    is => 'ro',
    lazy => 1,
    builder => '_syslog_open',
);

sub _syslog_open {
    my $self = shift;
    my $ident = $self->log_ident or return 0;
    my $opts = 'pid,ndelay';
    my $facility = 'local6';
    my $log;
    eval {
        Sys::Syslog::setlogsock('unix');
        openlog($ident, $opts, $facility);
        $log = $ident;
    };
    $log;
}

sub DEMOLISH {
    my $self = shift;
    closelog() if $self->log_open;
}

sub log {
    my ($self, $str) = @_;
    $self->log_open or return;
    $str = Dumper($str) if ref $str;
    syslog('debug', '%s', $str);
}

1;
