package FixMyStreet::App::Controller::Admin::ReportExtraFields;
use Moose;
use namespace::autoclean;
use List::MoreUtils qw(uniq);

BEGIN { extends 'Catalyst::Controller'; }


sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my @extras = $c->model('DB::ReportExtraField')->search(
        undef,
        {
            order_by => 'name'
        }
    );

    $c->stash->{extra_fields} = \@extras;
}

sub edit : Path : Args(1) {
    my ( $self, $c, $extra_id ) = @_;

    my $extra;
    if ( $extra_id eq 'new' ) {
        $extra = $c->model('DB::ReportExtraField')->new({});
    } else {
        $extra = $c->model('DB::ReportExtraField')->find( $extra_id )
            or $c->detach( '/page_error_404_not_found' );
    }

    if ($c->req->method eq 'POST') {
        $c->forward('/auth/check_csrf_token');

        foreach (qw/name cobrand language/) {
            $extra->$_($c->get_param($_));
        }
        $c->forward('/admin/update_extra_fields', [ $extra ]);

        $extra->update_or_insert;
    }

    $c->forward('/auth/get_csrf_token');
    $c->forward('/admin/fetch_languages');

    my @cobrands = uniq sort map { $_->{moniker} } FixMyStreet::Cobrand->available_cobrand_classes;
    $c->stash->{cobrands} = \@cobrands;

    $c->stash->{extra} = $extra;
}

__PACKAGE__->meta->make_immutable;

1;
