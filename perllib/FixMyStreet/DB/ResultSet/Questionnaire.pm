package FixMyStreet::DB::ResultSet::Questionnaire;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;
use File::Slurp;
use Utils;
use mySociety::EmailUtil;

sub send_questionnaires {
    my ( $rs, $params ) = @_;
    $rs->send_questionnaires_period( '4 weeks', $params );
    $rs->send_questionnaires_period( '26 weeks', $params )
        if $params->{site} eq 'emptyhomes';
}

sub send_questionnaires_period {
    my ( $rs, $period, $params ) = @_;

    # Select all problems that need a questionnaire email sending
    my $q_params = {
        state => [ 'confirmed', 'fixed' ],
        whensent => [
            '-and',
            { '!=', undef },
            { '<', \"ms_current_timestamp() - '$period'::interval" },
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
            '(select max(whenanswered) from questionnaire where me.id=problem_id)' => { '<', \"ms_current_timestamp() - '$period'::interval" }
        ];
    }

    my $unsent = FixMyStreet::App->model('DB::Problem')->search( $q_params, {
        order_by => { -desc => 'confirmed' }
    } );

    while (my $row = $unsent->next) {

        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($row->cobrand)->new();
        $cobrand->set_lang_and_domain($row->lang, 1);

        # Cobranded and non-cobranded messages can share a database. In this case, the conf file 
        # should specify a vhost to send the reports for each cobrand, so that they don't get sent 
        # more than once if there are multiple vhosts running off the same database. The email_host
        # call checks if this is the host that sends mail for this cobrand.
        next unless $cobrand->email_host;

        my $template;
        if ($params->{site} eq 'emptyhomes') {
            ($template = $period) =~ s/ //;
            $template = File::Slurp::read_file( FixMyStreet->path_to( "templates/email/emptyhomes/" . $row->lang . "/questionnaire-$template.txt" )->stringify );
        } else {
            $template = FixMyStreet->path_to( "templates", "email", $cobrand->moniker, "questionnaire.txt" )->stringify;
            $template = FixMyStreet->path_to( "templates", "email", "default", "questionnaire.txt" )->stringify
                unless -e $template;
            $template = File::Slurp::read_file( $template );
        }

        my %h = map { $_ => $row->$_ } qw/name title detail category/;
        $h{created} = Utils::prettify_duration( time() - $row->confirmed->epoch, 'week' );

        my $questionnaire = FixMyStreet::App->model('DB::Questionnaire')->create( {
            problem_id => $row->id,
            whensent => \'ms_current_timestamp()',
        } );

        # We won't send another questionnaire unless they ask for it (or it was
        # the first EHA questionnaire.
        $row->send_questionnaire( 0 )
            if $params->{site} ne 'emptyhomes' || $period eq '26 weeks';

        my $token = FixMyStreet::App->model("DB::Token")->new_result( {
            scope => 'questionnaire',
            data  => $questionnaire->id,
        } );
        $h{url} = $cobrand->base_url_for_emails($row->cobrand_data) . '/Q/' . $token->token;

        my $sender = $cobrand->contact_email;
        my $sender_name = _($cobrand->contact_name);
        $sender =~ s/team/fms-DO-NOT-REPLY/;

        print "Sending questionnaire " . $questionnaire->id . ", problem "
            . $row->id . ", token " . $token->token . " to "
            . $row->user->email . "\n"
            if $params->{verbose};

        my $result = FixMyStreet::App->send_email_cron(
            {
                _template_ => $template,
                _parameters_ => \%h,
                To => [ [ $row->user->email, $row->name ] ],
                From => [ $sender, $sender_name ],
            },
            $sender,
            [ $row->user->email ],
            $params->{nomail}
        );
        if ($result == mySociety::EmailUtil::EMAIL_SUCCESS) {
            print "  ...success\n" if $params->{verbose};
            $row->update();
            $token->insert();
        } else {
            print " ...failed\n" if $params->{verbose};
            $questionnaire->delete;
        }
    }
}

sub timeline {
    my ( $rs, $restriction ) = @_;

    return $rs->search(
        {
            -or => {
                whenanswered => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
                'me.whensent'  => { '>=', \"ms_current_timestamp()-'7 days'::interval" },
            },
            %{ $restriction },
        },
        {
            -select => [qw/me.*/],
            prefetch => [qw/problem/],
        }
    );
}

sub summary_count {
    my ( $rs, $restriction ) = @_;

    return $rs->search(
        $restriction,
        {
            group_by => [ \'whenanswered is not null' ],
            select   => [ \'(whenanswered is not null)', { count => 'me.id' } ],
            as       => [qw/answered questionnaire_count/],
            join     => 'problem'
        }
    );
}
1;
