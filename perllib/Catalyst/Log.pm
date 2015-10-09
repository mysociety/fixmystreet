package Catalyst::Log;

use Moose;
with 'MooseX::Emulate::Class::Accessor::Fast';

use Data::Dump;
use Class::MOP ();
use Carp qw/ cluck /;

our %LEVELS = (); # Levels stored as bit field, ergo debug = 1, warn = 2 etc
our %LEVEL_MATCH = (); # Stored as additive, thus debug = 31, warn = 30 etc

has level => (is => 'rw');
has _body => (is => 'rw');
has abort => (is => 'rw');
has _psgi_logger => (is => 'rw', predicate => '_has_psgi_logger', clearer => '_clear_psgi_logger');
has _psgi_errors => (is => 'rw', predicate => '_has_psgi_errors', clearer => '_clear_psgi_errors');

sub clear_psgi {
    my $self = shift;
    $self->_clear_psgi_logger;
    $self->_clear_psgi_errors;
}

sub psgienv {
    my ($self, $env) = @_;

    $self->_psgi_logger($env->{'psgix.logger'}) if $env->{'psgix.logger'};
    $self->_psgi_errors($env->{'psgi.errors'}) if $env->{'psgi.errors'};
}


{
    my @levels = qw[ debug info warn error fatal ];

    my $meta = Class::MOP::get_metaclass_by_name(__PACKAGE__);
    my $summed_level = 0;
    for ( my $i = $#levels ; $i >= 0 ; $i-- ) {

        my $name  = $levels[$i];

        my $level = 1 << $i;
        $summed_level |= $level;

        $LEVELS{$name} = $level;
        $LEVEL_MATCH{$name} = $summed_level;

       $meta->add_method($name, sub {
            my $self = shift;

            if ( $self->level & $level ) {
                $self->_log( $name, @_ );
            }
        });

        $meta->add_method("is_$name", sub {
            my $self = shift;
            return $self->level & $level;
        });;
    }
}

around new => sub {
    my $orig = shift;
    my $class = shift;
    my $self = $class->$orig;

    $self->levels( scalar(@_) ? @_ : keys %LEVELS );

    return $self;
};

sub levels {
    my ( $self, @levels ) = @_;
    $self->level(0);
    $self->enable(@levels);
}

sub enable {
    my ( $self, @levels ) = @_;
    my $level = $self->level;
    for(map { $LEVEL_MATCH{$_} } @levels){
      $level |= $_;
    }
    $self->level($level);
}

sub disable {
    my ( $self, @levels ) = @_;
    my $level = $self->level;
    for(map { $LEVELS{$_} } @levels){
      $level &= ~$_;
    }
    $self->level($level);
}

our $HAS_DUMPED;
sub _dump {
    my $self = shift;
    unless ($HAS_DUMPED++) {
        cluck("Catalyst::Log::_dump is deprecated and will be removed. Please change to using your own Dumper.\n");
    }
    $self->info( Data::Dump::dump(@_) );
}

sub _log {
    my $self    = shift;
    my $level   = shift;
    my $message = join( "\n", @_ );
    if ($self->can('_has_psgi_logger') and $self->_has_psgi_logger) {
        $self->_psgi_logger->({
                level => $level,
                message => $message,
            });
    } else {
        $message .= "\n" unless $message =~ /\n$/;
        my $body = $self->_body;
        $body .= sprintf( "[%s] %s", $level, $message );
        $self->_body($body);
    }
}

sub _flush {
    my $self = shift;
    if ( $self->abort || !$self->_body ) {
        $self->abort(undef);
    }
    else {
        $self->_send_to_log( $self->_body );
    }
    $self->_body(undef);
}

sub _send_to_log {
    my $self = shift;
    if ($self->can('_has_psgi_errors') and $self->_has_psgi_errors) {
        $self->_psgi_errors->print(@_);
    } else {
        print STDERR @_;
    }
}

# 5.7 compat code.
# Alias _body to body, add a before modifier to warn..
my $meta = __PACKAGE__->meta; # Calling meta method here fine as we happen at compile time.
$meta->add_method('body', $meta->get_method('_body'));
my %package_hash; # Only warn once per method, per package.
                  # I haven't provided a way to disable them, patches welcome.
$meta->add_before_method_modifier('body', sub {
    my $class = blessed(shift);
    $package_hash{$class}++ || do {
        warn("Class $class is calling the deprecated method Catalyst::Log->body method,\n"
            . "this will be removed in Catalyst 5.81");
    };
});
# End 5.70 backwards compatibility hacks.

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

__END__

=for stopwords psgienv

=head1 NAME

Catalyst::Log - Catalyst Log Class

=head1 SYNOPSIS

    $log = $c->log;
    $log->debug($message);
    $log->info($message);
    $log->warn($message);
    $log->error($message);
    $log->fatal($message);

    if ( $log->is_debug ) {
         # expensive debugging
    }


See L<Catalyst>.

=head1 DESCRIPTION

This module provides the default, simple logging functionality for Catalyst.
If you want something different set C<< $c->log >> in your application module,
e.g.:

    $c->log( MyLogger->new );

Your logging object is expected to provide the interface described here.
Good alternatives to consider are Log::Log4Perl and Log::Dispatch.

If you want to be able to log arbitrary warnings, you can do something along
the lines of

    $SIG{__WARN__} = sub { MyApp->log->warn(@_); };

however this is (a) global, (b) hairy and (c) may have unexpected side effects.
Don't say we didn't warn you.

=head1 LOG LEVELS

=head2 debug

    $log->is_debug;
    $log->debug($message);

=head2 info

    $log->is_info;
    $log->info($message);

=head2 warn

    $log->is_warn;
    $log->warn($message);

=head2 error

    $log->is_error;
    $log->error($message);

=head2 fatal

    $log->is_fatal;
    $log->fatal($message);

=head1 METHODS

=head2 new

Constructor. Defaults to enable all levels unless levels are provided in
arguments.

    $log = Catalyst::Log->new;
    $log = Catalyst::Log->new( 'warn', 'error' );

=head2 level

Contains a bitmask of the currently set log levels.

=head2 levels

Set log levels

    $log->levels( 'warn', 'error', 'fatal' );

=head2 enable

Enable log levels

    $log->enable( 'warn', 'error' );

=head2 disable

Disable log levels

    $log->disable( 'warn', 'error' );

=head2 is_debug

=head2 is_error

=head2 is_fatal

=head2 is_info

=head2 is_warn

Is the log level active?

=head2 abort

Should Catalyst emit logs for this request? Will be reset at the end of
each request.

*NOTE* This method is not compatible with other log apis, so if you plan
to use Log4Perl or another logger, you should call it like this:

    $c->log->abort(1) if $c->log->can('abort');

=head2 _send_to_log

 $log->_send_to_log( @messages );

This protected method is what actually sends the log information to STDERR.
You may subclass this module and override this method to get finer control
over the log output.

=head2 psgienv $env

    $log->psgienv($env);

NOTE: This is not meant for public consumption.

Set the PSGI environment for this request. This ensures logs will be sent to
the right place. If the environment has a C<psgix.logger>, it will be used. If
not, we will send logs to C<psgi.errors> if that exists. As a last fallback, we
will send to STDERR as before.

=head2 clear_psgi

Clears the PSGI environment attributes set by L</psgienv>.

=head2 meta

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
