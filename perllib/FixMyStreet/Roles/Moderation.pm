package FixMyStreet::Roles::Moderation;
use Moo::Role;

=head2 latest_moderation_log_entry

Return most recent AdminLog object concerning moderation

=cut

sub latest_moderation {
    my $self = shift;

    return $self->moderation_original_datas->search(
        $self->moderation_filter,
        { order_by => { -desc => 'id' } })->first;
}

sub latest_moderation_log_entry {
    my $self = shift;

    my $latest = $self->latest_moderation;
    return unless $latest;

    my $rs = $self->result_source->schema->resultset("AdminLog");
    my $log = $rs->search({
        object_id => $latest->id,
        object_type => 'moderation',
    })->first;
    return $log if $log;

    return $self->admin_log_entries->search({ action => 'moderation' }, { order_by => { -desc => 'id' } })->first;
}

=head2 moderation_history

Returns all moderation history, most recent first.

=cut

sub moderation_history {
    my $self = shift;
    return $self->moderation_original_datas->search(
        $self->moderation_filter,
        { order_by => { -desc => 'id' } })->all;
}

1;
