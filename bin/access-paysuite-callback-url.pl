use strict;
use warnings;

BEGIN {
    use File::Basename qw(dirname);
    use File::Spec;
    my $d = dirname(File::Spec->rel2abs($0));
    require "$d/../setenv.pl";
}

use Integrations::AccessPaySuite;

my $asp_i = Integrations::AccessPaySuite->new( {
    config => {
        endpoint => 'https://playpen.accesspaysuite.com',
        api_key => '',
        client_code => 'APIRTM',
        log_ident => 'staging.fixmystreet.com_bexley',
    }
} );

$asp_i->set_callback_url( 'contract', 'contract_updates' );
# Response:
# $VAR1 = {
#   'Message' => 'Updated url'
# };
