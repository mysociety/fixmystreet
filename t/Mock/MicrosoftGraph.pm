package t::Mock::MicrosoftGraph;

use Web::Simple;

sub dispatch_request {
    my $self = shift;

    sub (GET + /v1.0/users/*) {
        my ($self, $oid) = @_;
        my $json = '{"department":"Department","displayName":"Name"}';
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },

}

LWP::Protocol::PSGI->register(t::Mock::MicrosoftGraph->to_psgi_app, host => 'graph.microsoft.com');

__PACKAGE__->run_if_script;
