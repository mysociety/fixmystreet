package FixMyStreet::Cobrand::EmptyHomes;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

use FixMyStreet;
use mySociety::Locale;
use Carp;

sub path_to_web_templates {
    my $self = shift;
    return [ FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify ];
}

sub _fallback_body_sender {
    my ( $self, $body, $category ) = @_;

    return { method => 'EmptyHomes' };
};

=item

Return the base url for this cobranded site

=cut

sub base_url {
    my $base_url = FixMyStreet->config('BASE_URL');
    if ( $base_url !~ /emptyhomes/ ) {
        $base_url =~ s/http:\/\//http:\/\/emptyhomes\./g;
    }
    return $base_url;
}

sub area_types {
    [ 'DIS', 'LBO', 'MTD', 'UTA', 'LGD', 'COI' ]; # No CTY
}

sub base_url_with_lang {
    my $self = shift;

    my $base = $self->base_url;

    my $lang = $mySociety::Locale::lang;
    if ($lang eq 'cy') {
        $base =~ s{http://}{$&cy.};
    } else {
        $base =~ s{http://}{$&en.};
    }
    return $base;
}

sub languages { [ 'en-gb,English,en_GB', 'cy,Cymraeg,cy_GB' ] }
sub language_domain { 'FixMyStreet-EmptyHomes' }

=item shorten_recency_if_new_greater_than_fixed

For empty homes we don't want to shorten the recency

=cut

sub shorten_recency_if_new_greater_than_fixed {
    return 0;
}

=head2 default_photo_resize

Size that photos are to be resized to for display. If photos aren't
to be resized then return 0;

=cut

sub default_photo_resize { return '195x'; }

sub short_name {
    my $self = shift;
    my ($area) = @_;

    my $name = $area->{name} || $area->name;
    $name =~ s/ (Borough|City|District|County) Council$//;
    $name =~ s/ Council$//;
    $name =~ s/ & / and /;
    $name =~ s{/}{_}g;
    $name = URI::Escape::uri_escape_utf8($name);
    $name =~ s/%20/-/g;
    return $name;
}

=item council_rss_alert_options

Generate a set of options for council rss alerts. 

=cut

sub council_rss_alert_options {
    my $self = shift;
    my $all_councils = shift;
    my $c            = shift;

    my %councils = map { $_ => 1 } @{$self->area_types};

    my $num_councils = scalar keys %$all_councils;

    my ( @options, @reported_to_options );
    my ($council, $ward);
    foreach (values %$all_councils) {
        $_->{short_name} = $self->short_name( $_ );
        ( $_->{id_name} = $_->{short_name} ) =~ tr/+/_/;
        if ($councils{$_->{type}}) {
            $council = $_;
        } else {
            $ward = $_;
        }
    }

    push @options, {
        type      => 'council',
        id        => sprintf( 'council:%s:%s', $council->{id}, $council->{id_name} ),
        text      => sprintf( _('Problems within %s'), $council->{name}),
        rss_text  => sprintf( _('RSS feed of problems within %s'), $council->{name}),
        uri       => $c->uri_for( '/rss/reports/' . $council->{short_name} ),
    };
    push @options, {
        type     => 'ward',
        id       => sprintf( 'ward:%s:%s:%s:%s', $council->{id}, $ward->{id}, $council->{id_name}, $ward->{id_name} ),
        rss_text => sprintf( _('RSS feed of problems within %s ward'), $ward->{name}),
        text     => sprintf( _('Problems within %s ward'), $ward->{name}),
        uri      => $c->uri_for( '/rss/reports/' . $council->{short_name} . '/' . $ward->{short_name} ),
    };

    return ( \@options, @reported_to_options ? \@reported_to_options : undef );
}

sub report_form_extras {
    ( { name => 'address', required => 1 } )
}

sub front_stats_data {
    my ( $self ) = @_;
    my $key = "recent_new";
    my $result = Memcached::get($key);
    unless ($result) {
        $result = $self->problems->search(
            { state => [ FixMyStreet::DB::Result::Problem->visible_states() ] }
        )->count;
        foreach my $v (values %{$self->old_site_stats}) {
            $result += $v;
        }
        Memcached::set($key, $result, 3600);
    }
    return $result;
}

# A record of the number of reports from the Channel 4 site and other old data
sub old_site_stats {
    return {
        2223 => 95,
        2238 => 82,
        2245 => 54,
        2248 => 31,
        2250 => 132,
        2253 => 15,
        2255 => 25,
        2256 => 8,
        2257 => 3,
        2258 => 14,
        2259 => 5,
        2260 => 22,
        2261 => 12,
        2262 => 21,
        2263 => 14,
        2264 => 1,
        2267 => 1,
        2271 => 13,
        2272 => 7,
        2273 => 13,
        2274 => 7,
        2275 => 15,
        2276 => 14,
        2277 => 10,
        2278 => 7,
        2279 => 23,
        2280 => 16,
        2281 => 25,
        2282 => 14,
        2283 => 10,
        2284 => 22,
        2285 => 25,
        2286 => 32,
        2287 => 13,
        2288 => 13,
        2289 => 16,
        2290 => 18,
        2291 => 1,
        2292 => 9,
        2293 => 15,
        2294 => 16,
        2295 => 12,
        2296 => 4,
        2299 => 2,
        2300 => 1,
        2304 => 10,
        2305 => 17,
        2306 => 6,
        2307 => 11,
        2308 => 17,
        2309 => 9,
        2310 => 6,
        2311 => 9,
        2312 => 26,
        2313 => 2,
        2314 => 34,
        2315 => 18,
        2316 => 13,
        2317 => 17,
        2318 => 7,
        2319 => 14,
        2320 => 4,
        2321 => 20,
        2322 => 7,
        2323 => 10,
        2324 => 7,
        2325 => 15,
        2326 => 12,
        2327 => 25,
        2328 => 23,
        2329 => 11,
        2330 => 4,
        2331 => 29,
        2332 => 12,
        2333 => 7,
        2334 => 5,
        2335 => 16,
        2336 => 7,
        2337 => 7,
        2338 => 2,
        2339 => 12,
        2340 => 2,
        2341 => 7,
        2342 => 14,
        2343 => 20,
        2344 => 13,
        2345 => 17,
        2346 => 6,
        2347 => 4,
        2348 => 6,
        2349 => 18,
        2350 => 13,
        2351 => 11,
        2352 => 24,
        2353 => 10,
        2354 => 20,
        2355 => 14,
        2356 => 13,
        2357 => 14,
        2358 => 8,
        2359 => 6,
        2360 => 10,
        2361 => 36,
        2362 => 17,
        2363 => 8,
        2364 => 7,
        2365 => 8,
        2366 => 26,
        2367 => 19,
        2368 => 20,
        2369 => 8,
        2370 => 14,
        2371 => 79,
        2372 => 10,
        2373 => 5,
        2374 => 4,
        2375 => 12,
        2376 => 10,
        2377 => 24,
        2378 => 9,
        2379 => 8,
        2380 => 25,
        2381 => 13,
        2382 => 11,
        2383 => 16,
        2384 => 18,
        2385 => 12,
        2386 => 18,
        2387 => 5,
        2388 => 8,
        2389 => 12,
        2390 => 11,
        2391 => 23,
        2392 => 11,
        2393 => 16,
        2394 => 9,
        2395 => 27,
        2396 => 8,
        2397 => 27,
        2398 => 14,
        2402 => 1,
        2403 => 18,
        2404 => 14,
        2405 => 7,
        2406 => 9,
        2407 => 12,
        2408 => 3,
        2409 => 8,
        2410 => 23,
        2411 => 27,
        2412 => 9,
        2413 => 20,
        2414 => 96,
        2415 => 11,
        2416 => 20,
        2417 => 18,
        2418 => 24,
        2419 => 18,
        2420 => 7,
        2421 => 29,
        2427 => 7,
        2428 => 15,
        2429 => 18,
        2430 => 32,
        2431 => 9,
        2432 => 17,
        2433 => 8,
        2434 => 10,
        2435 => 14,
        2436 => 13,
        2437 => 11,
        2438 => 5,
        2439 => 4,
        2440 => 23,
        2441 => 8,
        2442 => 18,
        2443 => 12,
        2444 => 3,
        2445 => 8,
        2446 => 31,
        2447 => 15,
        2448 => 3,
        2449 => 12,
        2450 => 11,
        2451 => 8,
        2452 => 20,
        2453 => 25,
        2454 => 8,
        2455 => 6,
        2456 => 24,
        2457 => 6,
        2458 => 10,
        2459 => 15,
        2460 => 17,
        2461 => 20,
        2462 => 12,
        2463 => 16,
        2464 => 5,
        2465 => 14,
        2466 => 20,
        2467 => 14,
        2468 => 12,
        2469 => 4,
        2470 => 1,
        2471 => 1,
        2474 => 9,
        2475 => 12,
        2476 => 11,
        2477 => 9,
        2478 => 10,
        2479 => 21,
        2480 => 26,
        2481 => 30,
        2482 => 38,
        2483 => 46,
        2484 => 63,
        2485 => 7,
        2486 => 14,
        2487 => 16,
        2488 => 14,
        2489 => 39,
        2490 => 112,
        2491 => 79,
        2492 => 137,
        2493 => 55,
        2494 => 18,
        2495 => 41,
        2496 => 41,
        2497 => 22,
        2498 => 26,
        2499 => 46,
        2500 => 62,
        2501 => 90,
        2502 => 47,
        2503 => 32,
        2504 => 33,
        2505 => 47,
        2506 => 56,
        2507 => 26,
        2508 => 48,
        2509 => 47,
        2510 => 16,
        2511 => 6,
        2512 => 4,
        2513 => 41,
        2514 => 138,
        2515 => 48,
        2516 => 65,
        2517 => 35,
        2518 => 40,
        2519 => 31,
        2520 => 27,
        2521 => 25,
        2522 => 34,
        2523 => 27,
        2524 => 47,
        2525 => 22,
        2526 => 125,
        2527 => 126,
        2528 => 93,
        2529 => 23,
        2530 => 28,
        2531 => 24,
        2532 => 46,
        2533 => 22,
        2534 => 24,
        2535 => 27,
        2536 => 44,
        2537 => 54,
        2538 => 17,
        2539 => 13,
        2540 => 29,
        2541 => 15,
        2542 => 19,
        2543 => 14,
        2544 => 34,
        2545 => 30,
        2546 => 38,
        2547 => 32,
        2548 => 22,
        2549 => 37,
        2550 => 9,
        2551 => 41,
        2552 => 17,
        2553 => 36,
        2554 => 10,
        2555 => 20,
        2556 => 13,
        2557 => 19,
        2558 => 13,
        2559 => 23,
        2560 => 13,
        2561 => 62,
        2562 => 29,
        2563 => 31,
        2564 => 34,
        2565 => 57,
        2566 => 16,
        2567 => 22,
        2568 => 40,
        2569 => 5,
        2570 => 38,
        2571 => 17,
        2572 => 9,
        2573 => 12,
        2574 => 10,
        2575 => 16,
        2576 => 2,
        2577 => 28,
        2578 => 37,
        2579 => 79,
        2580 => 17,
        2581 => 734,
        2582 => 11,
        2583 => 23,
        2584 => 16,
        2585 => 4,
        2586 => 33,
        2587 => 3,
        2588 => 22,
        2589 => 19,
        2590 => 14,
        2591 => 9,
        2592 => 19,
        2593 => 11,
        2594 => 14,
        2595 => 13,
        2596 => 21,
        2597 => 10,
        2598 => 16,
        2599 => 26,
        2600 => 1,
        2601 => 19,
        2602 => 23,
        2603 => 12,
        2604 => 31,
        2605 => 30,
        2606 => 5,
        2607 => 32,
        2608 => 14,
        2609 => 27,
        2610 => 15,
        2611 => 20,
        2612 => 22,
        2613 => 20,
        2614 => 97,
        2615 => 29,
        2616 => 6,
        2617 => 34,
        2618 => 16,
        2619 => 25,
        2620 => 12,
        2621 => 29,
        2622 => 18,
        2623 => 12,
        2624 => 58,
        2625 => 54,
        2626 => 15,
        2627 => 1,
        2629 => 17,
        2630 => 22,
        2636 => 13,
        2637 => 13,
        2638 => 25,
        2639 => 57,
        2640 => 15,
        2641 => 11,
        2642 => 14,
        2643 => 38,
        2644 => 19,
        2645 => 6,
        2646 => 1,
        2647 => 16,
        2648 => 25,
        2649 => 38,
        2650 => 12,
        2651 => 78,
        2652 => 12,
        2654 => 16,
        2655 => 13,
        2656 => 15,
        2657 => 44,
        2658 => 53,
        16869 => 73,
        21068 => 44,
        21069 => 57,
        21070 => 20,
    };
}

1;

