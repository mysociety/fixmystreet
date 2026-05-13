package FixMyStreet::Roles::Syslog;

use Data::Dumper;
use Sys::Syslog ();

# Before Moo::Role so it's not imported

sub _redact {
    my $obj = shift;
    if (ref $obj eq 'HASH') {
        foreach (keys %$obj) {
            if (ref $obj->{$_}) {
                _redact($obj->{$_});
            } else {
                $obj->{$_} = '[REDACTED]' if $_ =~ /cardnumber|carddescription|accountnumber|sortcode/i;
            }
        }
    } elsif (ref $obj eq 'ARRAY') {
        foreach (@$obj) {
            _redact($_) if ref $_;
        }
    }
    return $obj;
}

use Moo::Role;

# We do force the connection to be a unix socket, because one side effect is we
# can set the ident per-call, unlike with native handling.
Sys::Syslog::setlogsock('unix');

# Syslog has a global ident, which we use to send to different outputs, so we
# call openlog on each log to make sure the ident is the correct one. We are
# not using `ndelay`, so only one connection should be made, at the first log.
sub log {
    my ($self, $str) = @_;

    if (ref $str) {
        $str = _redact($str);
        $str = Dumper($str);
    }

    my $ident = $self->log_ident or return;
    my $opts = '';
    my $facility = 'local6';
    Sys::Syslog::openlog($ident, $opts, $facility);

    Sys::Syslog::syslog('debug', '%s', $str);
}

1;
