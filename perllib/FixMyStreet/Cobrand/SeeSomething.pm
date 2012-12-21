package FixMyStreet::Cobrand::SeeSomething;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return [ 2520, 2522, 2514, 2546, 2519, 2538, 2535 ]; }
sub council_area { return 'West Midlands'; }
sub council_name { return 'See Something Say Something'; }
sub council_url { return 'seesomething'; }
sub area_types  { [ 'MTD' ] }
sub site_title { return 'See Something, Say Something'; }


sub site_restriction {
    my $self = shift;
    return { council => { IN => $self->council_id  } };
}

sub problems_clause {
    my $self = shift;
    return { council => { IN => $self->council_id  } };
}

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub council_check {
    my ( $self, $params, $context ) = @_;

    my $councils = $params->{all_councils};
    my $council_match = grep { $councils->{$_} } @{ $self->council_id };

    if ($council_match) {
        return 1;
    }

    return ( 0, "That location is not covered by See Something, Say Something" );
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'West Midlands';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        centre => '52.4803101685267,-2.2708272758854',
        span   => '1.4002794815887,2.06340043925997',
        bounds => [ 51.8259444771676, -3.23554082684068, 53.2262239587563, -1.17214038758071 ],
    };
}

sub example_places {
    return ( 'WS1 4NH', 'Austin Drive, Coventry' );
}

sub send_questionnaires {
    return 0;
}

sub ask_ever_reported {
    return 0;
}

sub report_sent_confirmation_email { 1; }

sub report_check_for_errors { return (); }

sub never_confirm_reports { 1; }

sub allow_anonymous_reports { 1; }

sub anonymous_account { return { name => 'anon user', email => 'anon@example.com' }; }

sub admin_pages {
    my $self = shift;

    return {
        'stats' => ['Reports', 0],
    };
};

sub admin_stats {
    my $self = shift;
    my $c = $self->{c};

    my %filters = ();

    if ( !$c->user_exists || !grep { $_ == $c->user->from_council } @{ $self->council_id } ) {
        $c->detach( '/page_error_404_not_found' );
    }

    if ( $c->req->param('category') ) {
        $filters{category} = $c->req->param('category');
    }

    if ( $c->req->param('subcategory') ) {
        $filters{subcategory} = $c->req->param('subcategory');
    }

    my $p = $c->model('DB::Problem')->search(
        {
            confirmed => { not => undef },
            %filters
        },
        {
                order_by => { -desc=> [ 'confirmed' ] }
        }
    );

    $c->stash->{reports} = $p;

    return 1;
}

1;

