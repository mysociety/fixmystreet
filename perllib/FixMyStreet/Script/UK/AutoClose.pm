package FixMyStreet::Script::UK::AutoClose;

use v5.14;
use warnings;

use Moo;
use Types::Standard qw(Bool InstanceOf Int Maybe);
use FixMyStreet::Script::ArchiveOldEnquiries;
use FixMyStreet::DB;

has commit => ( is => 'ro', default => 0 );

has body_name => ( is => 'ro' );
has category => ( is => 'ro' );

has states => ( is => 'ro', default => sub { [ FixMyStreet::DB::Result::Problem->open_states() ] } );

has retain_alerts => ( is => 'ro', isa => Bool );

has body => (
    is => 'lazy',
    isa => InstanceOf['FixMyStreet::DB::Result::Body'],
    default => sub {
        my $self = shift;
        my $body = FixMyStreet::DB->resultset('Body')->find({ name => $self->body_name });
        die "Can't find body\n" unless $body;
        return $body;
    }
);

has from => ( is => 'ro', isa => Maybe[Int] );
has to => ( is => 'ro' , isa => Int );

has now => (
    is => 'lazy',
    isa => InstanceOf['DateTime'],
    default => sub { DateTime->now->set_time_zone(FixMyStreet->local_time_zone) },
);

has from_date => (
    is => 'lazy',
    isa => Maybe[InstanceOf['DateTime']],
    default => sub {
        my $self = shift;
        return unless $self->from;
        my $days = $self->from * -1;
        my $date = $self->now->clone->add( days => $days );
        return $date;
    }
);

has to_date => (
    is => 'lazy',
    isa => InstanceOf['DateTime'],
    default => sub {
        my $self = shift;
        my $days = $self->to * -1;
        my $date = $self->now->clone->add( days => $days );
        return $date;
    }
);

has template_title => ( is => 'ro' );

has template => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $template;
        if ($self->template_title) {
            $template = FixMyStreet::DB->resultset("ResponseTemplate")->search({
                'me.body_id' => $self->body->id,
                'me.title' => $self->template_title,
            })->first;
        } else {
            $template = FixMyStreet::DB->resultset("ResponseTemplate")->search({
                'me.state' => 'closed',
                'me.auto_response' => 1,
                'me.body_id' => $self->body->id,
                ( 'contact.category' => $self->category ) x !!$self->category,
            }, {
                join => { contact_response_templates => 'contact' },
            })->first;
        }
        die "Could not find template" unless $template;
        return $template;
    },
);

sub close {
    my $self = shift;

    my $dtf = FixMyStreet::DB->schema->storage->datetime_parser;

    my $time_param;
    if ($self->from) {
        $time_param = [ -and =>
            { '>=', $dtf->format_datetime($self->from_date) },
            { '<', $dtf->format_datetime($self->to_date) }
        ];
    } else {
        $time_param = { '<', $dtf->format_datetime($self->to_date) };
    }

    my $reports = FixMyStreet::DB->resultset("Problem")->search({
        bodies_str => $self->body->id,
        state => $self->states,
        confirmed => $time_param,
        ( category => $self->category ) x !!$self->category,
    });

    # Provide some variables to the archiving script
    FixMyStreet::Script::ArchiveOldEnquiries::update_options({
        user => $self->body->comment_user->id,
        closure_text => $self->template->text,
        retain_alerts => $self->retain_alerts,
        commit => $self->commit,
    });

    # Close the reports
    FixMyStreet::Script::ArchiveOldEnquiries::close_problems($reports);
}

1;
