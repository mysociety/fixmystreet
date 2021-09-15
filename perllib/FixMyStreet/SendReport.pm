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
has 'success' => ( is => 'rw', isa => Bool, default => 0 );
has 'error' => ( is => 'rw', isa => Str, default => '' );
has 'unconfirmed_data' => ( 'is' => 'rw', isa => HashRef, default => sub { {} } );
has contact => ( is => 'rw' );

sub get_senders {
    my $self = shift;

    my %senders = map { $_ => 1 } $self->senders;

    return \%senders;
}

sub add_body {
    my $self = shift;
    my $body = shift;
    my $config = shift;

    push @{$self->bodies}, $body;
    $self->body_config->{ $body->id } = $config;
}

sub fetch_category {
    my ($self, $body, $row, $category_override) = @_;

    my $contact = $row->result_source->schema->resultset("Contact")->find( {
        body_id => $body->id,
        category => $category_override || $row->category,
    } );

    unless ($contact) {
        my $error = "Category " . $row->category . " does not exist for body " . $body->id . " and report " . $row->id . "\n";
        $self->error( "Failed to send over Open311\n" ) unless $self->error;
        $self->error( $self->error . "\n" . $error );
    }

    $self->contact($contact);
    return $contact;
}

1;
