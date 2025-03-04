use Test::MockTime qw(set_fixed_time);
use FixMyStreet::Test;
use WasteWorks::Costs;

my $bromley = FixMyStreet::Cobrand::Bromley->new; # Pro rata
my $brent = FixMyStreet::Cobrand::Brent->new; # Discount
my $kingston = FixMyStreet::Cobrand::Kingston->new; # Renews with end date, admin fee
my $sutton = FixMyStreet::Cobrand::Sutton->new; # Next month
my $merton = FixMyStreet::Cobrand::Merton->new;
my $bexley = FixMyStreet::Cobrand::Bexley->new; # First bin discount

set_fixed_time("2025-01-14T12:00:00Z");

my $mocked_service = {
    end_date => "2025-03-31T00:00:00Z",
};

FixMyStreet::override_config {
    COBRAND_FEATURES => {
        payment_gateway => {
            merton => { ggw_cost => 1000, ggw_sacks_cost => 750 },
            bromley => { ggw_cost => 7000, pro_rata_minimum => 1500, pro_rata_weekly => 100 },
            brent => { ggw_cost => 3000 },
            kingston => {
                ggw_cost => 5000, ggw_sacks_cost => 2500,
                ggw_new_bin_cost => 500, ggw_new_bin_first_cost => 1500,
                ggw_cost_renewal => 5500, ggw_sacks_cost_renewal => 2800,
            },
            sutton => { ggw_cost => [
                { start_date => '2025-01-01 00:00', cost => 1500 },
                { start_date => '2025-02-01 00:00', cost => 1700 },
            ] },
            bexley => {  ggw_first_bin_discount => 500, ggw_cost_first => 7500, ggw_cost => 5500 },
        },
        waste_features => {
            brent => { ggw_discount_as_percent => 20 },
        },
    },
}, sub {
    subtest 'per-thing' => sub {
        my $costs = WasteWorks::Costs->new({ cobrand => $merton, service => $mocked_service });
        is $costs->per_bin, 1000;
        is $costs->per_sack, 750;
        is $costs->per_bin_renewal, 1000;
        is $costs->per_sack_renewal, 750;
        is $costs->per_pro_rata_bin, 1000;
    };

    subtest 'bins' => sub {
        my $costs = WasteWorks::Costs->new({ cobrand => $bromley, service => $mocked_service });
        is $costs->bins, 7000;
        is $costs->bins(2), 14000;
        is $costs->pro_rata_cost(3), 7200;
    };

    subtest 'first bin a different price' => sub {
        my $costs = WasteWorks::Costs->new({ cobrand => $bexley });
        is $costs->bins, 7500;
        is $costs->bins(2), 7500+5500;
    };

    subtest 'first bin discounted' => sub {
        my $costs = WasteWorks::Costs->new({ cobrand => $bexley, discount => 0, first_bin_discount => 1, service => $mocked_service });
        is $costs->bins, 7000;
        is $costs->bins(2), 7000+5500;
    };

    subtest 'sacks' => sub {
        my $costs = WasteWorks::Costs->new({ cobrand => $merton });
        is $costs->sacks(1), 750;
        is $costs->sacks(3), 2250;
    };

    subtest 'sacks with no specified sack cost' => sub {
        my $costs = WasteWorks::Costs->new({ cobrand => $brent });
        is $costs->sacks, 3000;
        is $costs->sacks(3), 9000;
    };

    subtest 'discount' => sub {
        my $costs = WasteWorks::Costs->new({ cobrand => $brent, discount => 1, service => $mocked_service });
        is $costs->bins(2), 4800;
        is $costs->sacks(1), 2400;
        is $costs->per_bin, 2400;
        is $costs->per_bin_renewal, 2400;
    };

    subtest 'renewal' => sub {
        my $costs = WasteWorks::Costs->new({ cobrand => $kingston, service => $mocked_service });
        is $costs->bins_renewal(2), 11000;
        is $costs->sacks_renewal(3), 8400;
        is $costs->per_bin, 5000;
        is $costs->per_sack, 2500;
        is $costs->per_bin_renewal, 5500;
        is $costs->per_sack_renewal, 2800;
    };

    subtest 'admin fee' => sub {
        my $costs = WasteWorks::Costs->new({ cobrand => $kingston });
        is $costs->per_new_bin_first, 1500;
        is $costs->per_new_bin, 500;
        is $costs->new_bin_admin_fee(1), 1500;
        is $costs->new_bin_admin_fee(3), 2500;
    };

    subtest 'next month' => sub {
        my $costs = WasteWorks::Costs->new({ cobrand => $sutton });
        is_deeply $costs->next_month, { start_date => '2025-02-01T00:00:00', cost => 1700 };
    };
};

done_testing;
