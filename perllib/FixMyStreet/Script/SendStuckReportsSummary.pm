package FixMyStreet::Script::SendStuckReportsSummary;

use v5.14;
use warnings;

use FixMyStreet::DB;
use FixMyStreet::Email;
use Lingua::EN::Inflect qw(PL_N PL_V WORDLIST);

sub run {
    my $params = shift;
    my $cobrand = $params->{body}->get_cobrand_handler;

    my @stuck_reports = FixMyStreet::DB->resultset('Problem')->to_body($params->{body}->id)->search({
        category => $params->{categories},
        send_state => 'unprocessed',
        state => [ FixMyStreet::DB::Result::Problem::open_states() ],
        send_fail_count => { '>', 0 },
    })->order_by('-confirmed')->all;
    my $stuck_reports_count = scalar @stuck_reports;
    my $category_count = scalar @{$params->{categories}};

    foreach (@stuck_reports) {
        my $reason = $_->send_fail_reason;
        $reason =~ s/^.*?error: 500: //s;
        $reason =~ s/"MessageDetails".*/.../s;
        $reason =~ s/ at \/data\/vhost.*//s;
        $_->send_fail_reason($reason);
    }

    my @unconfirmed_reports;
    my $unconfirmed_reports_count;
    if ($params->{unconfirmed}) {
        @unconfirmed_reports = FixMyStreet::DB->resultset('Problem')->to_body($params->{body}->id)->search({
            category => $params->{categories},
            state => 'unconfirmed',
            -or => [
                extra => undef,
                -not => { extra => { '\?' => 'stuck_email_sent' } }
            ],
        })->order_by('-created')->all;
        $unconfirmed_reports_count = scalar @unconfirmed_reports;
    }

    my $overview = "There " . PL_V("is", $stuck_reports_count) . " $stuck_reports_count stuck " . PL_N("report", $stuck_reports_count);
    if ($params->{unconfirmed}) {
        $overview .= " and $unconfirmed_reports_count unconfirmed " . PL_N("report", $unconfirmed_reports_count);
    }
    $overview .= " for " . PL_N('category', $category_count) . " " . WORDLIST(map { "'$_'" } @{$params->{categories}});


    FixMyStreet::Email::send_cron(
        FixMyStreet::DB->schema,
        'stuck-reports-summary.txt',
        {
            body => $params->{body},
            cobrand => $cobrand,
            overview => $overview,
            stuck_reports => \@stuck_reports,
            unconfirmed_reports => \@unconfirmed_reports,
        },
        { To => $params->{email} },
        undef,    # env_from
        $params->{commit} ? 0 : 1,    # nomail
        $cobrand,
        "en-gb",
    );

    if ($params->{commit}) {
        foreach (@unconfirmed_reports) {
            $_->set_extra_metadata( stuck_email_sent => 1 );
            $_->update;
        }
    }
}

1;
