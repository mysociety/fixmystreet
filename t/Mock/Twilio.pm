package t::Mock::Twilio;

use Web::Simple;

has texts => (
    is => 'ro',
    default => sub { [] },
);

sub get_text_code {
    my $self = shift;
    my $text = shift @{$self->texts};
    return unless $text;
    my ($code) = $text->{Body} =~ /(\d+)/;
    return $code;
}

sub dispatch_request {
    my $self = shift;

    sub (POST + /2010-04-01/Accounts/*/Messages.json + %*) {
        my ($self, $sid, $data) = @_;
        push @{$self->texts}, $data;
        return [ 200, [ 'Content-Type' => 'application/json' ], [ '{}' ] ];
    },
}

__PACKAGE__->run_if_script;
