package FixMyStreet::Cobrand::BathNES;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmValidation';

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;

sub council_area_id { return 2551; }
sub council_area { return 'Bath and North East Somerset'; }
sub council_name { return 'Bath and North East Somerset Council'; }
sub council_url { return 'bathnes'; }

sub contact_email {
    my $self = shift;
    return join( '@', 'councilconnect_rejections', 'bathnes.gov.uk' );
}

sub suggest_duplicates { 1 }

sub admin_user_domain { 'bathnes.gov.uk' }

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    return 'https://fix.bathnes.gov.uk';
}

sub map_type { 'BathNES' }

sub on_map_default_status { 'open' }

sub example_places {
    return ( 'BA1 1JQ', "Lansdown Grove" );
}

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Bath and North East Somerset';

    # The council have provided a list of common typos which we should correct:
    my %replacements = (
        "broom" => "brougham",
        "carnarvon" => "caernarvon",
        "cornation" => "coronation",
        "beafort" => "beaufort",
        "beechan" => "beechen",
        "malreword" => "malreward",
        "canyerberry"=> "canterbury",
        "clairemont"=> "claremont",
        "salsbury"=> "salisbury",
        "solsberry"=> "solsbury",
        "lawn road" => "lorne",
        "new road high littleton" => "danis house",
    );

    foreach my $original (keys %replacements) {
        my $replacement = $replacements{$original};
        $string =~ s/$original/$replacement/ig;
    }

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.3559192103294,-2.47522827137605',
        span   => '0.166437921041471,0.429359043406088',
        bounds => [ 51.2730478766607, -2.70792015294201, 51.4394857977022, -2.27856110953593 ],
        string => $string,
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub send_questionnaires { 0 }

sub enable_category_groups { 1 }

sub default_map_zoom { 3 }

sub map_js_extra {
    my $self = shift;

    my $c = $self->{c};
    return unless $c->user_exists;

    my $banes_user = $c->user->from_body && $c->user->from_body->areas->{$self->council_area_id};
    if ( $banes_user || $c->user->is_superuser ) {
        return ['/cobrands/bathnes/staff.js'];
    }
}

sub category_extra_hidden {
    my ($self, $meta) = @_;
    my $code = $meta->{code};
    # These two are used in the non-Open311 'Street light fault' category.
    return 1 if $code eq 'unitid' || $code eq 'asset_details';
    return $self->SUPER::category_extra_hidden($meta);
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

    # Reports made via FMS.com or the app probably won't have a USRN
    # value because we don't display the adopted highways layer on those
    # frontends. Instead we'll look up the closest asset from the WFS
    # service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('site_code')) {
        if (my $usrn = $self->lookup_usrn($row)) {
            push @$extra,
                { name => 'site_code',
                value => $usrn };
        }
    }

    $row->set_extra_fields(@$extra);
}

sub available_permissions {
    my $self = shift;

    my $permissions = $self->SUPER::available_permissions();

    $permissions->{Problems}->{report_reject} = "Reject reports";
    $permissions->{Dashboard}->{export_extra_columns} = "Extra columns in CSV export";

    return $permissions;
}

sub report_sent_confirmation_email { 'id' }

sub lookup_usrn {
    my $self = shift;
    my $row = shift;

    my $buffer = 5; # metres
    my ($x, $y) = $row->local_coords;
    my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);

    my $uri = URI->new("https://isharemaps.bathnes.gov.uk/getows.ashx");
    $uri->query_form(
        REQUEST => "GetFeature",
        SERVICE => "WFS",
        SRSNAME => "urn:ogc:def:crs:EPSG::27700",
        TYPENAME => "AdoptedHighways",
        VERSION => "1.1.0",
        mapsource => "BathNES/WFS",
        outputformat => "application/json",
        BBOX => "$w,$s,$e,$n"
    );

    my $response = get($uri);

    my $j = JSON->new->utf8->allow_nonref;
    try {
        $j = $j->decode($response);
        return $j->{features}->[0]->{properties}->{usrn};
    } catch {
        # There was either no asset found, or an error with the WFS
        # call - in either case let's just proceed without the USRN.
        return;
    }

}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a location in ' . $self->council_area;
}

sub categories_restriction {
    my ($self, $rs) = @_;
    # Categories covering BANES have a mixture of Open311 and Email
    # send methods. BANES only want specific categories to be visible on their
    # cobrand, not the email categories from FMS.com.
    # The FMS.com categories have a devolved send_method set to Email, so we can
    # filter these out.
    # NB. BANES have a 'Street Light Fault' category that has its
    # send_method set to 'Email::BathNES' (to use a custom template) which must
    # be show on the cobrand.
    return $rs->search( { -or => [
        'me.send_method' => undef, # Open311 categories
        'me.send_method' => '', # Open311 categories that have been edited in the admin
        'me.send_method' => 'Email::BathNES', # Street Light Fault
        'me.send_method' => 'Blackhole', # Parks categories
    ] } );
}

# Do a manual prefetch, as easier than sorting out quoting 'user'
sub _dashboard_user_lookup {
    my $self = shift;
    my $c = $self->{c};

    # Fetch all the relevant user IDs, and look them up
    my @user_ids = $c->stash->{objects_rs}->search({}, { columns => [ 'user_id' ] })->all;
    @user_ids = map { $_->user_id } @user_ids;
    @user_ids = $c->model('DB::User')->search(
        { id => { -in => \@user_ids } },
        { columns => [ 'id', 'email', 'phone' ] })->all;

    # Plus all staff users for contributed_by lookup
    push @user_ids, $c->model('DB::User')->search(
        { from_body => { '!=' => undef } },
        { columns => [ 'id', 'email', 'phone' ] })->all;

    my %user_lookup = map { $_->id => { email => $_->email, phone => $_->phone } } @user_ids;
    return \%user_lookup;
}

sub dashboard_export_updates_add_columns {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->user->has_body_permission_to('export_extra_columns');

    push @{$c->stash->{csv}->{headers}}, "Staff User";
    push @{$c->stash->{csv}->{headers}}, "User Email";
    push @{$c->stash->{csv}->{columns}}, "staff_user";
    push @{$c->stash->{csv}->{columns}}, "user_email";

    my $user_lookup = $self->_dashboard_user_lookup;

    $c->stash->{csv}->{extra_data} = sub {
        my $report = shift;

        my $staff_user = '';
        if ( my $contributed_by = $report->get_extra_metadata('contributed_by') ) {
            $staff_user = $user_lookup->{$contributed_by}{email};
        }

        return {
            user_email => $user_lookup->{$report->user_id}{email} || '',
            staff_user => $staff_user,
        };
    };
}

sub dashboard_export_problems_add_columns {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->user->has_body_permission_to('export_extra_columns');

    $c->stash->{csv}->{headers} = [
        @{ $c->stash->{csv}->{headers} },
        "User Email",
        "User Phone",
        "Staff User",
        "Attribute Data",
    ];

    $c->stash->{csv}->{columns} = [
        @{ $c->stash->{csv}->{columns} },
        "user_email",
        "user_phone",
        "staff_user",
        "attribute_data",
    ];

    my $user_lookup = $self->_dashboard_user_lookup;

    $c->stash->{csv}->{extra_data} = sub {
        my $report = shift;

        my $staff_user = '';
        if ( my $contributed_by = $report->get_extra_metadata('contributed_by') ) {
            $staff_user = $user_lookup->{$contributed_by}{email};
        }
        my $attribute_data = join "; ", map { $_->{name} . " = " . $_->{value} } @{ $report->get_extra_fields };
        return {
            user_email => $user_lookup->{$report->user_id}{email} || '',
            user_phone => $user_lookup->{$report->user_id}{phone} || '',
            staff_user => $staff_user,
            attribute_data => $attribute_data,
        };
    };
}

1;
