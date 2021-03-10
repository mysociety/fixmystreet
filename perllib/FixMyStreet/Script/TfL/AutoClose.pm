package FixMyStreet::Script::TfL::AutoClose;

use v5.14;

use Moo;
use CronFns;
use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use Types::Standard qw(InstanceOf Maybe);

has commit => ( is => 'ro', default => 0 );

has verbose => ( is => 'ro', default => 0 );

has body => (
    is => 'lazy',
    isa => Maybe[InstanceOf['FixMyStreet::DB::Result::Body']],
    default => sub {
        my $body = FixMyStreet::DB->resultset('Body')->find({ name => 'TfL' });
        return $body;
    }
);

has days => (
    is => 'ro',
    default => 28
);

sub close {
    my $self = shift;

    die "Can't find body\n" unless $self->body;
    warn "DRY RUN: use --commit to close reports\n" unless $self->commit;
    my $categories = $self->categories;
    $self->close_reports($categories);
}

has newest => (
    is => 'lazy',
    isa => InstanceOf['DateTime'],
    default => sub {
        my $self = shift;
        my $days = $self->days * -1;
        my $date = DateTime->now->add( days => $days )->truncate( to => 'day' );
        return $date;
    }
);

# get list of cateories that have a response template for the fixed
# state marked as auto-response.
sub categories {
    my $self = shift;

    my $templates = FixMyStreet::DB->resultset('ResponseTemplate')->search({
        state => 'fixed - council',
        auto_response => 1,
        body_id => $self->body->id,
    });

    my %categories;
    for my $template ( $templates->all ) {
        map { $categories{$_->category} = $template; } $template->contacts->all;
    }

    return \%categories;
}

# find reports in relevant categories that have been set to action
# scheduled for 30 days.
sub close_reports {
    my ($self, $categories) = @_;

    my $dtf = FixMyStreet::DB->schema->storage->datetime_parser;

    my $reports = FixMyStreet::DB->resultset('Problem')->search({
        category => { -in => [ keys %$categories ] },
        'me.state' => 'action scheduled',
        bodies_str => $self->body->id,
        'comments.state' => 'confirmed',
        'comments.problem_state' => 'action scheduled',
    },
    {
        group_by => 'me.id',
        join => [ 'comments' ],
        having => \[ 'MIN(comments.confirmed) < ?', $dtf->format_datetime($self->newest) ]
    });

    my $count = 0;
    for my $r ( $reports->all ) {
        my $comments = FixMyStreet::DB->resultset('Comment')->search(
            { problem_id => $r->id },
            { order_by => 'confirmed' }
        );
        my $old_state = '';
        my $last_change;
        while ( my $c = $comments->next ) {
            my $new_state = $c->problem_state || '';
            if ( $new_state eq 'action scheduled' && $new_state ne $old_state) {
                $last_change = $c->confirmed;
            }
            $old_state = $new_state if $new_state;
        }
        next unless defined $last_change && $last_change < $self->newest;
        if ($self->commit) {
            $r->update({
                state => 'fixed - council',
                lastupdate => \'current_timestamp',
            });
            my $c = FixMyStreet::DB->resultset('Comment')->new(
                {
                    problem => $r,
                    text => $categories->{$r->category}->text,
                    state => 'confirmed',
                    problem_state => 'fixed - council',
                    user => $self->body->comment_user,
                    confirmed => \'current_timestamp'
                }
            );
            $c->insert;
        }
        $count++;
    }

    say "$count reports closed" if $self->verbose;

    return 1;
}

1;
