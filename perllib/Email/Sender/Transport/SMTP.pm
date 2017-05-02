package Email::Sender::Transport::SMTP;
# ABSTRACT: send email over SMTP
$Email::Sender::Transport::SMTP::VERSION = '1.300030';
use Moo;

use Email::Sender::Failure::Multi;
use Email::Sender::Success::Partial;
use Email::Sender::Role::HasMessage ();
use Email::Sender::Util;
use MooX::Types::MooseLike::Base qw(Bool Int Str HashRef);
use Net::SMTP 3.07; # SSL support, fixed datasend

use utf8 (); # See below. -- rjbs, 2015-05-14
use version ();

#pod =head1 DESCRIPTION
#pod
#pod This transport is used to send email over SMTP, either with or without secure
#pod sockets (SSL/TLS).  It is one of the most complex transports available, capable
#pod of partial success.
#pod
#pod For a potentially more efficient version of this transport, see
#pod L<Email::Sender::Transport::SMTP::Persistent>.
#pod
#pod =head1 ATTRIBUTES
#pod
#pod The following attributes may be passed to the constructor:
#pod
#pod =over 4
#pod
#pod =item C<host>: the name of the host to connect to; defaults to C<localhost>
#pod
#pod =item C<ssl>: if 'starttls', use STARTTLS; if 'ssl' (or 1), connect securely;
#pod otherwise, no security
#pod
#pod =item C<ssl_options>: passed to Net::SMTP constructor for 'ssl' connections or
#pod to starttls for 'starttls' connections; should contain extra options for
#pod IO::Socket::SSL
#pod
#pod =item C<port>: port to connect to; defaults to 25 for non-SSL, 465 for 'ssl',
#pod 587 for 'starttls'
#pod
#pod =item C<timeout>: maximum time in secs to wait for server; default is 120
#pod
#pod =cut

sub BUILD {
  my ($self) = @_;
  Carp::croak("do not pass port number to SMTP transport in host, use port parameter")
    if $self->host =~ /:/;
}

has host => (is => 'ro', isa => Str, default => sub { 'localhost' });
has ssl  => (is => 'ro', isa => Str, default => sub { 0 });

has _security => (
  is   => 'ro',
  lazy => 1,
  init_arg => undef,
  default  => sub {
    my $ssl = $_[0]->ssl;
    return '' unless $ssl;
    $ssl = lc $ssl;
    return 'starttls' if 'starttls' eq $ssl;
    return 'ssl' if $ssl eq 1 or $ssl eq 'ssl';

    Carp::cluck(qq{true "ssl" argument to Email::Sender::Transport::SMTP should be 'ssl' or 'startls' or '1' but got '$ssl'});

    return 1;
  },
);

has ssl_options => (is => 'ro', isa => HashRef, default => sub {  {}  });

has port => (
  is  => 'ro',
  isa => Int,
  lazy    => 1,
  default => sub {
    return $_[0]->_security eq 'starttls' ? 587
         : $_[0]->_security eq 'ssl'      ? 465
         :                                   25
  },
);

has timeout => (is => 'ro', isa => Int, default => sub { 120 });

#pod =item C<sasl_username>: the username to use for auth; optional
#pod
#pod =item C<sasl_password>: the password to use for auth; required if C<username> is provided
#pod
#pod =item C<allow_partial_success>: if true, will send data even if some recipients were rejected; defaults to false
#pod
#pod =cut

has sasl_username => (is => 'ro', isa => Str);
has sasl_password => (is => 'ro', isa => Str);

has allow_partial_success => (is => 'ro', isa => Bool, default => sub { 0 });

#pod =item C<helo>: what to say when saying HELO; no default
#pod
#pod =item C<localaddr>: local address from which to connect
#pod
#pod =item C<localport>: local port from which to connect
#pod
#pod =cut

has helo      => (is => 'ro', isa => Str);
has localaddr => (is => 'ro');
has localport => (is => 'ro', isa => Int);

#pod =item C<debug>: if true, put the L<Net::SMTP> object in debug mode
#pod
#pod =back
#pod
#pod =cut

has debug => (is => 'ro', isa => Bool, default => sub { 0 });

# I am basically -sure- that this is wrong, but sending hundreds of millions of
# messages has shown that it is right enough.  I will try to make it textbook
# later. -- rjbs, 2008-12-05
sub _quoteaddr {
  my $addr       = shift;
  my @localparts = split /\@/, $addr;
  my $domain     = pop @localparts;
  my $localpart  = join q{@}, @localparts;

  return $addr # The first regex here is RFC 821 "specials" excepting dot.
    unless $localpart =~ /[\x00-\x1F\x7F<>\(\)\[\]\\,;:@"]/
    or     $localpart =~ /^\./
    or     $localpart =~ /\.$/;
  return join q{@}, qq("$localpart"), $domain;
}

sub _smtp_client {
  my ($self) = @_;

  my $class = "Net::SMTP";

  my $smtp = $class->new( $self->_net_smtp_args );

  unless ($smtp) {
    $self->_throw(
      sprintf "unable to establish SMTP connection to %s port %s",
        $self->host,
        $self->port,
    );
  }

  if ($self->_security eq 'starttls') {
    $self->_throw("can't STARTTLS: " . $smtp->message)
      unless $smtp->starttls(%{ $self->ssl_options });
  }

  if ($self->sasl_username) {
    $self->_throw("sasl_username but no sasl_password")
      unless defined $self->sasl_password;

    unless ($smtp->auth($self->sasl_username, $self->sasl_password)) {
      if ($smtp->message =~ /MIME::Base64|Authen::SASL/) {
        Carp::confess("SMTP auth requires MIME::Base64 and Authen::SASL");
      }

      $self->_throw('failed AUTH', $smtp);
    }
  }

  return $smtp;
}

sub _net_smtp_args {
  my ($self) = @_;

  return (
    $self->host,
    Port    => $self->port,
    Timeout => $self->timeout,
    Debug   => $self->debug,

    (($self->_security eq 'ssl')
      ? (SSL => 1, %{ $self->ssl_options })
      : ()),

    defined $self->helo      ? (Hello     => $self->helo)      : (),
    defined $self->localaddr ? (LocalAddr => $self->localaddr) : (),
    defined $self->localport ? (LocalPort => $self->localport) : (),
  );
}

sub _throw {
  my ($self, @rest) = @_;
  Email::Sender::Util->_failure(@rest)->throw;
}

sub send_email {
  my ($self, $email, $env) = @_;

  Email::Sender::Failure->throw("no valid addresses in recipient list")
    unless my @to = grep { defined and length } @{ $env->{to} };

  my $smtp = $self->_smtp_client;

  my $FAULT = sub { $self->_throw($_[0], $smtp); };

  $smtp->mail(_quoteaddr($env->{from}))
    or $FAULT->("$env->{from} failed after MAIL FROM");

  my @failures;
  my @ok_rcpts;

  for my $addr (@to) {
    if ($smtp->to(_quoteaddr($addr))) {
      push @ok_rcpts, $addr;
    } else {
      # my ($self, $error, $smtp, $error_class, @rest) = @_;
      push @failures, Email::Sender::Util->_failure(
        undef,
        $smtp,
        recipients => [ $addr ],
      );
    }
  }

  # This logic used to include: or (@ok_rcpts == 1 and $ok_rcpts[0] eq '0')
  # because if called without SkipBad, $smtp->to can return 1 or 0.  This
  # should not happen because we now always pass SkipBad and do the counting
  # ourselves.  Still, I've put this comment here (a) in memory of the
  # suffering it caused to have to find that problem and (b) in case the
  # original problem is more insidious than I thought! -- rjbs, 2008-12-05

  if (
    @failures
    and ((@ok_rcpts == 0) or (! $self->allow_partial_success))
  ) {
    $failures[0]->throw if @failures == 1;

    my $message = sprintf '%s recipients were rejected during RCPT',
      @ok_rcpts ? 'some' : 'all';

    Email::Sender::Failure::Multi->throw(
      message  => $message,
      failures => \@failures,
    );
  }

  # restore Pobox's support for streaming, code-based messages, and arrays here
  # -- rjbs, 2008-12-04

  $smtp->data                        or $FAULT->("error at DATA start");

  my $msg_string = $email->as_string;
  my $hunk_size  = $self->_hunk_size;

  while (length $msg_string) {
    my $next_hunk = substr $msg_string, 0, $hunk_size, '';
    $smtp->datasend($next_hunk) or $FAULT->("error at during DATA");
  }

  $smtp->dataend                     or $FAULT->("error at after DATA");

  my $message = $smtp->message;

  $self->_message_complete($smtp);

  # We must report partial success (failures) if applicable.
  return $self->success({ message => $message }) unless @failures;
  return $self->partial_success({
    message => $message,
    failure => Email::Sender::Failure::Multi->new({
      message  => 'some recipients were rejected during RCPT',
      failures => \@failures
    }),
  });
}

sub _hunk_size { 2**20 } # send messages to DATA in hunks of 1 mebibyte

sub success {
  my $self = shift;
  my $success = Moo::Role->create_class_with_roles('Email::Sender::Success', 'Email::Sender::Role::HasMessage')->new(@_);
}

sub partial_success {
  my $self = shift;
  my $partial_success = Moo::Role->create_class_with_roles('Email::Sender::Success::Partial', 'Email::Sender::Role::HasMessage')->new(@_);
}

sub _message_complete { $_[1]->quit; }

#pod =head1 PARTIAL SUCCESS
#pod
#pod If C<allow_partial_success> was set when creating the transport, the transport
#pod may return L<Email::Sender::Success::Partial> objects.  Consult that module's
#pod documentation.
#pod
#pod =cut

with 'Email::Sender::Transport';
no Moo;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Email::Sender::Transport::SMTP - send email over SMTP

=head1 VERSION

version 1.300030

=head1 DESCRIPTION

This transport is used to send email over SMTP, either with or without secure
sockets (SSL/TLS).  It is one of the most complex transports available, capable
of partial success.

For a potentially more efficient version of this transport, see
L<Email::Sender::Transport::SMTP::Persistent>.

=head1 ATTRIBUTES

The following attributes may be passed to the constructor:

=over 4

=item C<host>: the name of the host to connect to; defaults to C<localhost>

=item C<ssl>: if 'starttls', use STARTTLS; if 'ssl' (or 1), connect securely;
otherwise, no security

=item C<ssl_options>: passed to Net::SMTP constructor for 'ssl' connections or
to starttls for 'starttls' connections; should contain extra options for
IO::Socket::SSL

=item C<port>: port to connect to; defaults to 25 for non-SSL, 465 for 'ssl',
587 for 'starttls'

=item C<timeout>: maximum time in secs to wait for server; default is 120

=item C<sasl_username>: the username to use for auth; optional

=item C<sasl_password>: the password to use for auth; required if C<username> is provided

=item C<allow_partial_success>: if true, will send data even if some recipients were rejected; defaults to false

=item C<helo>: what to say when saying HELO; no default

=item C<localaddr>: local address from which to connect

=item C<localport>: local port from which to connect

=item C<debug>: if true, put the L<Net::SMTP> object in debug mode

=back

=head1 PARTIAL SUCCESS

If C<allow_partial_success> was set when creating the transport, the transport
may return L<Email::Sender::Success::Partial> objects.  Consult that module's
documentation.

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
