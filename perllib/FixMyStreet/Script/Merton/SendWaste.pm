package FixMyStreet::Script::Merton::SendWaste;

use Moo;
use FixMyStreet::DB;
use FixMyStreet::Queue::Item::Report;
use FixMyStreet::SendReport::Open311;
use Open311;
use Integrations::Echo;

has body => (
    is => 'ro',
    default => sub { FixMyStreet::DB->resultset('Body')->find( { name => 'Merton Council' } ) or die $! }
);

sub echo_available {
    my $self = shift;
    my $cobrand = FixMyStreet::Cobrand::Merton->new;
    my $result = $cobrand->waste_check_downtime_file;
    return 0 if $result->{state} eq 'down';
    return 1;
}

sub check_payments {
    my ($self) = @_;
    my $problems = FixMyStreet::DB->resultset('Problem')->to_body($self->body->id)->search({
        -or => [
            { state => 'unconfirmed', category => 'Garden Subscription' },
            { state => 'confirmed', category => 'Bulky collection' },
        ],
        -not => { extra => { '\?' => 'payment_reference' } },
        created => [ -and => { '<', \"current_timestamp - '15 minutes'::interval" }, { '>=', \"current_timestamp - '1 hour'::interval" } ],
    });
    while (my $row = $problems->next) {
        my $cobrand = $row->get_cobrand_logged;
        my $query_id = $row->get_extra_metadata('scpReference') or next; # Problem fetching unique ID from payment provider
        my ($error, $reference) = $cobrand->cc_check_payment_and_update($query_id, $row);
        if ($reference) {
            $row->waste_confirm_payment($reference);
        }
    }
}

sub send_reports {
    my ($self) = @_;

    my $problems = $self->_problems;

    my $recent = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->subtract(minutes => 15);
    while (my $row = $problems->next) {
        if ($row->category eq 'Bulky collection' && $row->confirmed >= $recent) {
            next;
        }
        unless ($row->get_extra_metadata('no_echo')) {
            $self->set_echo_id($row) or next; # skip if no echo_id
        }

        my $item = FixMyStreet::Queue::Item::Report->new( report => $row );
        FixMyStreet::DB->schema->cobrand($item->cobrand);
        $item->cobrand->set_lang_and_domain($row->lang, 1);
        $item->_create_vars;
        $item->h->{sending_to_crimson} = 1;

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
        external_id => { '!=' => undef },
        cobrand_data => 'waste',
        cobrand => 'merton',
        -not => { extra => { '\?' => 'sent_to_crimson' } },
    });
}

sub set_echo_id {
    my ($self, $problem) = @_;

    unless ($problem->get_extra_field_value('echo_id')) {
        my $cobrand = $problem->get_cobrand_logged;
        my $cfg = $cobrand->feature('echo');
        my $echo = Integrations::Echo->new(%$cfg);
        my $event = $echo->GetEvent($problem->external_id);
        return unless $event && $event->{Id};

        my $db = FixMyStreet::DB->schema->storage;
        $db->txn_do(sub {
            my $row2 = FixMyStreet::DB->resultset('Problem')->search({ id => $problem->id }, { for => \'UPDATE' })->single;
            $row2->update_extra_field({
                name => 'echo_id',
                value => $event->{Id},
            });
            $row2->update;
        });
    }

    return 1;
}

sub send_comments {
    my ($self) = @_;
    my $comments = $self->_comments;

    while (my $row = $comments->next) {
        my $problem = $row->problem;

        my $cobrand = $problem->get_cobrand_logged;
        FixMyStreet::DB->schema->cobrand($cobrand);
        $cobrand->set_lang_and_domain($problem->lang, 1);

        my $cfg = $cobrand->feature('echo');
        my %o311_cfg = (
            jurisdiction => '',
            endpoint => $cfg->{open311_endpoint},
            api_key => $cfg->{open311_api_key},
            extended_statuses => $self->body->send_extended_statuses,
            fixmystreet_body => $self->body,
            use_customer_reference => 1,
        );
        my $o = Open311->new(%o311_cfg);
        $problem->set_extra_metadata( customer_reference => $problem->get_extra_metadata('crimson_external_id') );
        my $id = $o->post_service_request_update( $row );
        if ( $id ) {
            $row->set_extra_metadata( sent_to_crimson => 1 );
            $row->set_extra_metadata( crimson_external_id => $id );
            $row->update;
        } else {
            STDERR->print("Failed to post over Open311\n\n" . $o->error . "\n");
        }
    }
}

sub _comments {
    my $self = shift;
    FixMyStreet::DB->resultset('Comment')->to_body($self->body->id)->search({
        'problem.cobrand_data' => 'waste',
        'problem.cobrand' => 'merton',
        'problem.extra' => { '\?' => 'sent_to_crimson' },
        'me.external_id' => \'is not null',
        -or => [
            'me.extra' => undef,
            -not => { 'me.extra' => { '\?' => 'sent_to_crimson' } },
        ],
    }, {
        prefetch => 'problem',
    });
}

1;
