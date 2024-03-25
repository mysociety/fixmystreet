package FixMyStreet::Script::Merton::SendWaste;

use Moo;
use FixMyStreet::DB;
use FixMyStreet::Queue::Item::Report;
use FixMyStreet::SendReport::Open311;

has body => (
    is => 'ro',
    default => sub { FixMyStreet::DB->resultset('Body')->find( { name => 'Merton Council' } ) or die $! }
);

sub send_reports {
    my ($self, $cobrand) = @_;

    my $problems = $self->_problems;

    while (my $row = $problems->next) {
        my $item = FixMyStreet::Queue::Item::Report->new( report => $row );
        FixMyStreet::DB->schema->cobrand($item->cobrand);
        $item->cobrand->set_lang_and_domain($row->lang, 1);
        $item->_create_vars;

        my $cfg = $item->cobrand->feature('echo');
        my $body = FixMyStreet::DB->resultset("Body")->new({
            id => $self->body->id,
            jurisdiction => '',
            endpoint => $cfg->{open311_endpoint},
            api_key => $cfg->{open311_api_key},
        });
        my $sender_info = {
            method => 'Open311',
            config => $body,
        };
        my $reporter = FixMyStreet::SendReport::Open311->new;
        $reporter->add_body( $body, $sender_info->{config} );
        $item->_set_reporters([$reporter]);
        $item->_send;
        if ($reporter->success) {
            $row->discard_changes;
            $row->set_extra_metadata( sent_to_crimson => 1 );
            $row->update;
        }
    }
}

sub _problems {
    my $self = shift;
    FixMyStreet::DB->resultset('Problem')->to_body($self->body->id)->search({
        state => { -not_in => [ FixMyStreet::DB::Result::Problem::hidden_states ] },
        cobrand_data => 'waste',
        cobrand => 'merton',
        -not => { extra => { '\?' => 'sent_to_crimson' } },
    });
}

1;
