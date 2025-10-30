package FixMyStreet::App::Controller::Waste::AccessPaySuite;

use FixMyStreet::Script::Bexley::CancelGardenWaste;
use JSON::MaybeXS;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

sub contract_updates : Path('/waste/access_paysuite/contract_updates') : Args(0) {
    my ( $self, $c ) = @_;

    my $canceller = FixMyStreet::Script::Bexley::CancelGardenWaste->new(
        cobrand => $c->cobrand,
        verbose => 1,
    );

    my $content = $c->req->body_data;

    if ( $content->{NewStatus} eq 'Cancelled' ) {
        eval{
            $canceller->cancel_from_aps( $content->{Id}, $content->{ReportMessage} )
        };
# warn "====\n\t" . $@ . "\n====";
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
