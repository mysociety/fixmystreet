package FixMyStreet::Script::Waste::CheckPayments;

use Moo;
with 'FixMyStreet::Roles::Syslog';
use FixMyStreet::DB;

has cobrand => ( is => 'ro' );

has log_ident => ( is => 'ro', default => 'www.fixmystreet.com_checkpayments' );

sub check_payments {
    my $self = shift;
    my $cobrand = $self->cobrand;
    FixMyStreet::Map::set_map_class($cobrand);
    my $problems = FixMyStreet::DB->resultset('Problem')->to_body($cobrand->body->id)->search({
        -or => [
            { state => 'unconfirmed', category => 'Garden Subscription' },
            { state => 'confirmed', category => 'Bulky collection' },
        ],
        -not => { extra => { '\?' => 'payment_reference' } },
        created => [ -and => { '<', \"current_timestamp - '15 minutes'::interval" }, { '>=', \"current_timestamp - '1 hour'::interval" } ],
    });
    while (my $row = $problems->next) {
        $cobrand->set_lang_and_domain($row->lang, 1);
        my ($error, $reference);
        if (my $scp = $row->get_extra_metadata('scpReference')) {
            ($error, $reference) = $cobrand->cc_check_payment_and_update($scp, $row);
        } elsif (my $apn = $row->get_extra_metadata('apnReference')) {
            ($error, $reference) = $cobrand->paye_check_payment_and_update($apn, $row);
        }
        $self->log("Checked " . $row->id . ", ref " . ($reference||'-') . ", error " . ($error||'-'));
        if ($reference) {
            $row->waste_confirm_payment($reference);
        }
    }
}

1;
