package Open311::GetUpdates;

use Moo;
extends 'Open311::UpdatesBase';

use Open311;

has '+send_comments_flag' => ( default => 0 );
has ext_to_int_map => ( is => 'rw' );

has report_criteria => ( is => 'ro', default => sub { {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        external_id => { '!=', '' },
    } } );

sub process_body {
    my ($self) = @_;

    my $reports = $self->schema->resultset('Problem')
        ->to_body($self->current_body)
        ->search($self->report_criteria);

    my @reports = $reports->all;
    $self->update_reports(\@reports);
}

sub update_reports {
    my ( $self, $reports ) = @_;
    return unless @$reports;

    my $requests = $self->current_open311->get_service_requests( {
        report_ids => [ map { $_->external_id } @$reports ],
    } );

    $self->ext_to_int_map({ map { $_->external_id => $_ } @$reports });
    for my $request (@$requests) {
        $request->{description} = $request->{status_notes};

        my $p = $self->find_problem($request) or next;
        next if $request->{comment_time} < $p->lastupdate;
        # But what if update at our end later than update their end...

        $self->process_update($request, $p);
    }
}

sub _find_problem {
    my ($self, $criteria) = @_;
    my $problem = $self->ext_to_int_map->{$criteria->{external_id}};
    return $problem;
}

1;
