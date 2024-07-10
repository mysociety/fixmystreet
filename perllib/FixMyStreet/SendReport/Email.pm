package FixMyStreet::SendReport::Email;

use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use FixMyStreet::Email;
use Utils::Email;

BEGIN { extends 'FixMyStreet::SendReport'; }

has to => ( is => 'ro', isa => ArrayRef, default => sub { [] } );
has bcc => ( is => 'ro', isa => ArrayRef, default => sub { [] } );

has use_verp => ( is => 'ro', isa => Int, default => 1 );
has use_replyto => ( is => 'ro', isa => Int, default => 0 );

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    my $all_confirmed = 1;
    foreach my $body ( @{ $self->bodies } ) {

        my $contact = $self->fetch_category($body, $row) or next;

        my ($body_email, $state, $note) = ( $contact->email, $contact->state, $contact->note );

        if ($state eq 'unconfirmed') {
            $all_confirmed = 0;
            $note = 'Body ' . $row->bodies_str . ' deleted'
                unless $note;
            $body_email = 'N/A' unless $body_email;
            $self->unconfirmed_data->{$body_email}{$row->category}{count}++;
            $self->unconfirmed_data->{$body_email}{$row->category}{note} = $note;
        }

        my @emails;
        # allow multiple emails per contact
        if ( $body_email =~ /,/ ) {
            @emails = split(/,/, $body_email);
        } else {
            @emails = ( $body_email );
        }
        for my $email ( @emails ) {
            push @{ $self->to }, [ $email, $body->name ];
        }
    }

    return $all_confirmed && @{$self->to};
}

sub get_template {
    my ( $self, $row ) = @_;

    return 'submit.txt';
}

sub send_from {
    my ( $self, $row ) = @_;
    return [ $row->user->email, $row->name ];
}

sub envelope_sender {
    my ($self, $row) = @_;

    my $cobrand = $row->get_cobrand_logged;
    if ($self->use_verp && $row->user->email && $row->user->email_verified) {
        return FixMyStreet::Email::unique_verp_id([ 'report', $row->id ], $cobrand->call_hook('verp_email_domain'));
    }
    return $cobrand->do_not_reply_email;
}

sub send {
    my $self = shift;
    my ( $row, $h ) = @_;

    my $recips = @{$self->to} ? 1 : $self->build_recipient_list( $row, $h );

    # on a staging server send emails to ourselves rather than the bodies
    if (FixMyStreet->staging_flag('send_reports', 0) && !FixMyStreet->test_mode) {
        $recips = 1;
        @{$self->to} = [ $row->user->email, $self->to->[0][1] || $row->name ];
    }

    unless ($recips) {
        $self->error( 'No recipients' );
        return;
    }

    my ($verbose, $nomail) = CronFns::options();
    my $cobrand = $row->get_cobrand_logged;
    $cobrand = $cobrand->call_hook(get_body_handler_for_problem => $row) || $cobrand;

    my $params = {
        To => $self->to,
    };

    $params->{Bcc} = $self->bcc if @{$self->bcc};

    my $sender = $self->envelope_sender($row);
    if ($row->user->email && $row->user->email_verified) {
        $params->{From} = $self->send_from( $row );
    } else {
        my $name = sprintf(_("On behalf of %s"), @{ $self->send_from($row) }[1]);
        $params->{From} = [ $sender, $name ];
    }

    my $use_reply_to = $cobrand->feature('always_use_reply_to');

    if ( $self->use_replyto
      || $use_reply_to
      || FixMyStreet::Email::test_dmarc($params->{From}[0])
      || Utils::Email::same_domain($params->{From}, $params->{To})) {
        $params->{'Reply-To'} = [ $params->{From} ];
        $params->{From} = [ $sender, $params->{From}[1] ];
    }

    $cobrand->call_hook(munge_sendreport_params => $row, $h, $params);

    my $result = FixMyStreet::Email::send_cron($row->result_source->schema,
        $self->get_template($row), {
            %$h,
            cobrand => $cobrand, # For correct logo that uses cobrand object
        },
        $params, $sender, $nomail, $cobrand, $row->lang);

    unless ($result) {
        $row->update_extra_metadata(sent_to => email_list($params->{To}));
        $self->success(1);
    } else {
        $self->error( 'Failed to send email' );
    }
}

sub email_list {
    my $list = shift;
    my @list = map { ref $_ ? $_->[0] : $_ } @$list;
    return \@list;
}

1;
