package FixMyStreet::SendReport::Email;

use Moo;
use FixMyStreet::Email;
use Utils::Email;

BEGIN { extends 'FixMyStreet::SendReport'; }

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    my $all_confirmed = 1;
    foreach my $body ( @{ $self->bodies } ) {

        my $contact = $row->result_source->schema->resultset("Contact")->not_deleted->find( {
            body_id => $body->id,
            category => $row->category
        } );

        my ($body_email, $state, $note) = ( $contact->email, $contact->state, $contact->note );

        $body_email = swandt_contact($row->latitude, $row->longitude)
            if ($body->areas->{2427} || $body->areas->{2429}) && $body_email eq 'SPECIAL';

        unless ($state eq 'confirmed') {
            $all_confirmed = 0;
            $note = 'Body ' . $row->bodies_str . ' deleted'
                unless $note;
            $body_email = 'N/A' unless $body_email;
            $self->unconfirmed_counts->{$body_email}{$row->category}++;
            $self->unconfirmed_notes->{$body_email}{$row->category} = $note;
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
        return 1;
    }

    my ($verbose, $nomail) = CronFns::options();
    my $cobrand = $row->get_cobrand_logged;
    $cobrand = $cobrand->call_hook(get_body_handler_for_problem => $row) || $cobrand;

    my $params = {
        To => $self->to,
    };

    $cobrand->call_hook(munge_sendreport_params => $row, $h, $params);

    $params->{Bcc} = $self->bcc if @{$self->bcc};

    my $sender;
    if ($row->user->email && $row->user->email_verified) {
        $sender = FixMyStreet::Email::unique_verp_id('report', $row->id);
        $params->{From} = $self->send_from( $row );
    } else {
        $sender = FixMyStreet->config('DO_NOT_REPLY_EMAIL');
        my $name = sprintf(_("On behalf of %s"), @{ $self->send_from($row) }[1]);
        $params->{From} = [ $sender, $name ];
    }

    if (FixMyStreet::Email::test_dmarc($params->{From}[0])
      || Utils::Email::same_domain($params->{From}, $params->{To})) {
        $params->{'Reply-To'} = [ $params->{From} ];
        $params->{From} = [ $sender, $params->{From}[1] ];
    }

    my $result = FixMyStreet::Email::send_cron($row->result_source->schema,
        $self->get_template($row), $h,
        $params, $sender, $nomail, $cobrand, $row->lang);

    unless ($result) {
        $self->success(1);
    } else {
        $self->error( 'Failed to send email' );
    }

    return $result;
}

# SW&T has different contact addresses depending upon the old district
sub swandt_contact {
    my $district = _get_district_for_contact(@_);
    my $email;
    $email = ['customerservices', 'westsomerset'] if $district == 2427;
    $email = ['enquiries', 'tauntondeane'] if $district == 2429;
    return join('@', $email->[0], $email->[1] . '.gov.uk');
}

sub _get_district_for_contact {
    my ( $lat, $lon ) = @_;
    my $district =
      FixMyStreet::MapIt::call( 'point', "4326/$lon,$lat", type => 'DIS' );
    ($district) = keys %$district;
    return $district;
}

1;
