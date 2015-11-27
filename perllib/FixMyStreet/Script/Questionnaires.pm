package FixMyStreet::Script::Questionnaires;

use strict;
use warnings;
use Utils;
use FixMyStreet::DB;
use FixMyStreet::Email;
use FixMyStreet::Cobrand;

sub send {
    my ( $params ) = @_;
    send_questionnaires_period( '4 weeks', $params );
    send_questionnaires_period( '26 weeks', $params )
        if $params->{site} eq 'emptyhomes';
}

sub send_questionnaires_period {
    my ( $period, $params ) = @_;

    my $rs = FixMyStreet::DB->resultset('Questionnaire');

    # Select all problems that need a questionnaire email sending
    my $q_params = {
        state => [ FixMyStreet::DB::Result::Problem::visible_states() ],
        whensent => [
            '-and',
            { '!=', undef },
            { '<', \"current_timestamp - '$period'::interval" },
        ],
        send_questionnaire => 1,
    };
    # FIXME Do these a bit better...
    if ($params->{site} eq 'emptyhomes' && $period eq '4 weeks') {
        $q_params->{'(select max(whensent) from questionnaire where me.id=problem_id)'} = undef;
    } elsif ($params->{site} eq 'emptyhomes' && $period eq '26 weeks') {
        $q_params->{'(select max(whensent) from questionnaire where me.id=problem_id)'} = { '!=', undef };
    } else {
        $q_params->{'-or'} = [
            '(select max(whensent) from questionnaire where me.id=problem_id)' => undef,
            '(select max(whenanswered) from questionnaire where me.id=problem_id)' => { '<', \"current_timestamp - '$period'::interval" }
        ];
    }

    my $unsent = FixMyStreet::DB->resultset('Problem')->search( $q_params, {
        order_by => { -desc => 'confirmed' }
    } );

    while (my $row = $unsent->next) {

        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($row->cobrand)->new();
        $cobrand->set_lang_and_domain($row->lang, 1);

        # Not all cobrands send questionnaires
        next unless $cobrand->send_questionnaires;
        next if $row->is_from_abuser;

        # Cobranded and non-cobranded messages can share a database. In this case, the conf file 
        # should specify a vhost to send the reports for each cobrand, so that they don't get sent 
        # more than once if there are multiple vhosts running off the same database. The email_host
        # call checks if this is the host that sends mail for this cobrand.
        next unless $cobrand->email_host;

        my $template;
        if ($params->{site} eq 'emptyhomes') {
            ($template = $period) =~ s/ //;
            $template = Utils::read_file( FixMyStreet->path_to( "templates/email/emptyhomes/" . $row->lang . "/questionnaire-$template.txt" )->stringify );
        } else {
            $template = FixMyStreet->get_email_template($cobrand->moniker, $row->lang, 'questionnaire.txt');
        }

        my %h = map { $_ => $row->$_ } qw/name title detail category/;
        $h{created} = Utils::prettify_duration( time() - $row->confirmed->epoch, 'week' );

        my $questionnaire = $rs->create( {
            problem_id => $row->id,
            whensent => \'current_timestamp',
        } );

        # We won't send another questionnaire unless they ask for it (or it was
        # the first EHA questionnaire.
        $row->send_questionnaire( 0 )
            if $params->{site} ne 'emptyhomes' || $period eq '26 weeks';

        my $token = FixMyStreet::DB->resultset("Token")->new_result( {
            scope => 'questionnaire',
            data  => $questionnaire->id,
        } );
        $h{url} = $cobrand->base_url($row->cobrand_data) . '/Q/' . $token->token;

        print "Sending questionnaire " . $questionnaire->id . ", problem "
            . $row->id . ", token " . $token->token . " to "
            . $row->user->email . "\n"
            if $params->{verbose};

        my $result = FixMyStreet::Email::send_cron(
            $rs->result_source->schema,
            {
                _template_ => $template,
                _parameters_ => \%h,
                To => [ [ $row->user->email, $row->name ] ],
            },
            undef,
            $params->{nomail},
            $cobrand
        );
        unless ($result) {
            print "  ...success\n" if $params->{verbose};
            $row->update();
            $token->insert();
        } else {
            print " ...failed\n" if $params->{verbose};
            $questionnaire->delete;
        }
    }
}

1;
