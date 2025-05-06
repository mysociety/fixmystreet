package FixMyStreet::Script::SendStuckReportsSummary;

use v5.14;
use warnings;

use FixMyStreet::DB;
use FixMyStreet::Email;
use Lingua::EN::Inflect qw(PL_N PL_V WORDLIST);

sub run {
    my $params = shift;
    my $cobrand = $params->{body}->get_cobrand_handler;

    my $resultset = FixMyStreet::DB->resultset('Problem')->to_body($params->{body}->id);
    my @stuck_reports = $resultset->search({
        category => $params->{categories},
        send_state => 'unprocessed',
        state => [ FixMyStreet::DB::Result::Problem::open_states() ],
        send_fail_count => { '>', 0 },
    })->order_by('-confirmed')->all;

    foreach (@stuck_reports) {
        my $reason = $_->send_fail_reason;
        $reason =~ s/^.*?error: 500: //s;
        $reason =~ s/"MessageDetails".*/.../s;
        $reason =~ s/ at \/data\/vhost.*//s;
        $_->send_fail_reason($reason);
    }

    send_email('stuck', $params, $cobrand, \@stuck_reports);

    if ($params->{unconfirmed}) {
        my @unconfirmed_reports = $resultset->search({
            category => $params->{categories},
            state => 'unconfirmed',
            -or => [
                extra => undef,
                -not => { extra => { '\?' => 'stuck_email_sent' } }
            ],
        })->order_by('-created')->all;

        send_email('unconfirmed', $params, $cobrand, \@unconfirmed_reports);

        if ($params->{commit}) {
            foreach (@unconfirmed_reports) {
                $_->set_extra_metadata( stuck_email_sent => 1 );
                $_->update;
            }
        }
    }
}

sub send_email {
    my ($type, $params, $cobrand, $reports) = @_;

    my $count = scalar @$reports;
    my $category_count = scalar @{$params->{categories}};
    my $overview = "There " . PL_V("is", $count) . " $count $type " . PL_N("report", $count);
    $overview .= " for " . PL_N('category', $category_count) . " " . WORDLIST(map { "'$_'" } @{$params->{categories}});

    FixMyStreet::Email::send_cron(
        FixMyStreet::DB->schema,
        'stuck-reports-summary.txt',
        {
            body => $params->{body},
            cobrand => $cobrand,
            overview => $overview,
            $type eq 'stuck' ? (stuck_reports => $reports) : (unconfirmed_reports => $reports),
        },
        { To => $params->{email} },
        undef,    # env_from
        $params->{commit} ? 0 : 1,    # nomail
        $cobrand,
        "en-gb",
    );
}

1;
