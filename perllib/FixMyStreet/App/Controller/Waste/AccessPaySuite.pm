package FixMyStreet::App::Controller::Waste::AccessPaySuite;

use JSON::MaybeXS;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

sub contract_updates : Path('/waste/access_paysuite/contract_updates') : Args(0) {
    my ( $self, $c ) = @_;

    warn "====\n\t" . "DUMP:" . "\n====";
    use Data::Dumper;
    $Data::Dumper::Indent = 1;
    $Data::Dumper::Maxdepth = 3;
    $Data::Dumper::Sortkeys = 1;
    # warn Dumper $c->req->body->getlines;
    warn Dumper $c->req->body_data;

    my $content = $c->req->body_data;

    if ( $content->{NewStatus} eq 'Cancelled' ) {
        # TODO
        # Find matching subscription in our DB
        # and send a cancellation request to Agile

        # TODO Do we need to raise a cancellation report our end?

        my $report = $c->model('DB::Problem')->search({
            category => 'Garden Subscription',
            title => ['Garden Subscription - New', 'Garden Subscription - Renew'],
            extra => {
                '@>' => encode_json(
                    {   direct_debit_contract_id => $content->{Id} }
                )
                },
        })->order_by('-id')->first;

        warn "====\n\t" . "DUMP:" . "\n====";
        use Data::Dumper;
        $Data::Dumper::Indent = 1;
        $Data::Dumper::Maxdepth = 3;
        $Data::Dumper::Sortkeys = 1;
        warn Dumper $report;
    }

    $c->response->status(200);
    $c->response->body('OK');
}

# TODO Payment updates, e.g. for failed/'Unpaid'
# Can we do this directly? We do not seem to store Access PaySuite
# payment IDs anywhere
sub payment_updates : Path('/waste/access_paysuite/payment_updates') : Args(0) {

}

1;
