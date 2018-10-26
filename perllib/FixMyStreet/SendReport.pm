package FixMyStreet::SendReport;

use Moo;
use MooX::Types::MooseLike::Base qw(:all);

use Module::Pluggable
    sub_name    => 'senders',
    search_path => __PACKAGE__,
    except => 'FixMyStreet::SendReport::Email::SingleBodyOnly',
    require     => 1;

has 'body_config' => ( is => 'rw', isa => HashRef, default => sub { {} } );
has 'bodies' => ( is => 'rw', isa => ArrayRef, default => sub { [] } );
has 'to' => ( is => 'rw', isa => ArrayRef, default => sub { [] } );
has 'bcc' => ( is => 'rw', isa => ArrayRef, default => sub { [] } );
has 'success' => ( is => 'rw', isa => Bool, default => 0 );
has 'error' => ( is => 'rw', isa => Str, default => '' );
has 'unconfirmed_counts' => ( 'is' => 'rw', isa => HashRef, default => sub { {} } );
has 'unconfirmed_notes' => ( 'is' => 'rw', isa => HashRef, default => sub { {} } );


sub should_skip {
    my $self  = shift;
    my $row   = shift;
    my $debug = shift;

    return 0 unless $row->send_fail_count;
    return 0 if $debug;

    my $now = DateTime->now( time_zone => FixMyStreet->local_time_zone );
    my $diff = $now - $row->send_fail_timestamp;

    my $backoff = $row->send_fail_count > 1 ? 30 : 5;
    return $diff->in_units( 'minutes' ) < $backoff;
}

sub get_senders {
    my $self = shift;

    my %senders = map { $_ => 1 } $self->senders;

    return \%senders;
}

sub reset {
    my $self = shift;

    $self->bodies( [] );
    $self->body_config( {} );
    $self->to( [] );
    $self->bcc( [] );
}

sub add_body {
    my $self = shift;
    my $body = shift;
    my $config = shift;

    push @{$self->bodies}, $body;
    $self->body_config->{ $body->id } = $config;
}

1;
