package FixMyStreet::App::Controller::Waste::AccessPaySuite;

use JSON::MaybeXS;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

sub contract_updates : Path('/waste/access_paysuite/contract_updates') : Args(0) {
    my ( $self, $c ) = @_;

    my $content = $c->req->body_data;

    if ( $content->{NewStatus} eq 'Cancelled' ) {
        my $report = $c->model('DB::Problem')->search({
            category => 'Garden Subscription',
            title => ['Garden Subscription - New', 'Garden Subscription - Renew'],
            extra => {
                '@>' => encode_json(
                    {   direct_debit_contract_id => $content->{Id} }
                )
                },
        })->order_by('-id')->first;

        my $data = {};
        $data->{name} = $report->user->name;
        for my $field (qw(longitude latitude)) {
            $c->stash->{$field} = $report->$field;
        };

        $c->stash->{contacts} = [ $c->model('DB::Contact')->search({
            category => 'Cancel Garden Subscription'
        }) ];
        $c->stash->{orig_sub} = $report;
        $c->stash->{property}{uprn} = $report->get_extra_field_value('uprn');
        $c->set_param('token', $c->forward('/auth/get_csrf_token'));
        $c->forward('/waste/garden/process_garden_cancellation', [$data]);
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
