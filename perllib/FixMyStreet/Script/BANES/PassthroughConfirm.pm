package FixMyStreet::Script::BANES::PassthroughConfirm;

use Moo;
use FixMyStreet::DB;
use FixMyStreet::Queue::Item::Report;
use FixMyStreet::SendReport::Open311;
use Open311;

has body => (
    is => 'ro',
    default => sub { FixMyStreet::DB->resultset('Body')->find( { name => 'Bath and North East Somerset Council' } ) or die $! }
);

sub send_reports {
    my ($self) = @_;

    my $problems = $self->_problems;

    while (my $row = $problems->next) {
        my $item = FixMyStreet::Queue::Item::Report->new( report => $row );
        FixMyStreet::DB->schema->cobrand($item->cobrand);
        my $confirm_id = $row->external_id;
        $item->cobrand->set_lang_and_domain($row->lang, 1);
        $item->_create_vars;
        $item->h->{sending_to_banes_passthrough} = 1;
        my $sender_info = {
            method => 'Open311',
            config => $self->body,
        };
        my $reporter = FixMyStreet::SendReport::Open311->new;
        $reporter->add_body( $self->body, $sender_info->{config} );
        $item->_set_reporters([$reporter]);
        my $service_code = 'Passthrough-' . $row->contact->email;
        $item->h->{alternative_service_code} = $service_code;
        $item->_send;
        if ($reporter->success) {
            $row->discard_changes;
            $row->set_extra_metadata('sent_to_banes_passthrough' => 1);
            $row->set_extra_metadata('passthrough_id' => $row->external_id);
            $row->external_id($confirm_id);
            $row->update;
        } else {
            STDERR->print("Failed to post over Open311\n\n" . $reporter->error . "\n");
        }
    }
};

sub send_comments {
    my ($self) = @_;
    my $comments = $self->_comments;
    while (my $row = $comments->next) {
        my $problem = $row->problem;
        my $confirm_id = $row->external_id;
        my $cobrand = $problem->get_cobrand_logged;
        FixMyStreet::DB->schema->cobrand($cobrand);
        $cobrand->set_lang_and_domain($problem->lang, 1);
        my $service_code = 'Passthrough-' . $row->problem->contact->email;
        my %o311_cfg = (
            jurisdiction => 'banes',
            endpoint => $self->body->endpoint,
            api_key => $self->body->api_key,
            extended_statuses => $self->body->send_extended_statuses,
            fixmystreet_body => $self->body,
            use_customer_reference => 1,
            service_code => $service_code,
        );
        my $o = Open311->new(%o311_cfg);
        $problem->set_extra_metadata( customer_reference => $problem->get_extra_metadata('passthrough_id') );
        my $id = $o->post_service_request_update( $row );
        if ( $id ) {
            $row->external_id($confirm_id);
            $row->set_extra_metadata( sent_to_banes_passthrough => 1 );
            $row->set_extra_metadata( passthrough_id => $id );
            $row->update;
        } else {
            STDERR->print("Failed to post over Open311\n\n" . $o->error . "\n");
        }
    }
}

sub _problems {
    my $self = shift;
    FixMyStreet::DB->resultset('Problem')->to_body($self->body->id)->search({
        'me.state' => { -not_in => [ FixMyStreet::DB::Result::Problem::hidden_states ] },
        external_id => { '!=' => undef },
        bodies_str => $self->body->id,
        'contact.email' => { -not_like => '%@%' },
        -or => [
            'me.extra' => undef,
            -not => { 'me.extra' => { '\?' => 'sent_to_banes_passthrough' } },
        ],
    }, {
        prefetch => 'contact',
    }

    );
};

sub _comments {
    my $self = shift;
    FixMyStreet::DB->resultset('Comment')->to_body($self->body->id)->search({
         'problem.bodies_str' => $self->body->id,
         'problem.extra' => { '\?' => 'sent_to_banes_passthrough' },
         'me.external_id' => \'is not null',
        -or => [
            'me.extra' => undef,
            -not => { 'me.extra' => { '\?' => 'sent_to_banes_passthrough' } },
        ],
    }, {
        prefetch => 'problem',
    });
}

1;
