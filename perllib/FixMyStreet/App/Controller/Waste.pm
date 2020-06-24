package FixMyStreet::App::Controller::Waste;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use utf8;
use Lingua::EN::Inflect qw( NUMWORDS );
use FixMyStreet::App::Form::Waste::UPRN;
use FixMyStreet::App::Form::Waste::AboutYou;
use FixMyStreet::App::Form::Waste::Request;
use FixMyStreet::App::Form::Waste::Report;
use FixMyStreet::App::Form::Field::JSON;

sub auto : Private {
    my ( $self, $c ) = @_;
    my $cobrand_check = $c->cobrand->feature('waste');
    $c->detach( '/page_error_404_not_found' ) if !$cobrand_check;
    return 1;
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if (my $uprn = $c->get_param('address')) {
        $c->detach('redirect_to_uprn', [ $uprn ]);
    }

    $c->stash->{title} = 'What is your address?';
    my $form = FixMyStreet::App::Form::Waste::UPRN->new( cobrand => $c->cobrand );
    $form->process( params => $c->req->body_params );
    if ($form->validated) {
        my $addresses = $form->value->{postcode};
        $form = address_list_form($addresses);
    }
    $c->stash->{form} = $form;
}

sub address_list_form {
    my $addresses = shift;
    HTML::FormHandler->new(
        field_list => [
            address => {
                required => 1,
                type => 'Select',
                widget => 'RadioGroup',
                label => 'Select an address',
                tags => { last_differs => 1, small => 1 },
                options => $addresses,
            },
            go => {
                type => 'Submit',
                value => 'Continue',
                element_attr => { class => 'govuk-button' },
            },
        ],
    );
}

sub redirect_to_uprn : Private {
    my ($self, $c, $uprn) = @_;
    my $uri = '/waste/uprn/' . $uprn;
    my $type = $c->get_param('type') || '';
    $uri .= '/request' if $type eq 'request';
    $uri .= '/report' if $type eq 'report';
    $c->res->redirect($uri);
    $c->detach;
}

sub uprn : Chained('/') : PathPart('waste/uprn') : CaptureArgs(1) {
    my ($self, $c, $uprn) = @_;

    if ($uprn eq 'missing') {
        $c->stash->{template} = 'waste/missing.html';
        $c->detach;
    }

    $c->forward('/auth/get_csrf_token');

    my $property = $c->stash->{property} = $c->cobrand->call_hook(look_up_property => $uprn);
    $c->detach( '/page_error_404_not_found', [] ) unless $property;

    $c->stash->{uprn} = $uprn;
    $c->stash->{latitude} = $property->{latitude};
    $c->stash->{longitude} = $property->{longitude};

    $c->stash->{service_data} = $c->cobrand->call_hook(bin_services_for_address => $property) || [];
    $c->stash->{services} = { map { $_->{service_id} => $_ } @{$c->stash->{service_data}} };
}

sub bin_days : Chained('uprn') : PathPart('') : Args(0) {
    my ($self, $c) = @_;
}

sub calendar : Chained('uprn') : PathPart('calendar.ics') : Args(0) {
    my ($self, $c) = @_;
    $c->res->header(Content_Type => 'text/calendar');
    require Data::ICal::RFC7986;
    require Data::ICal::Entry::Event;
    my $calendar = Data::ICal::RFC7986->new(
        calname => 'Bin calendar',
        rfc_strict => 1,
        auto_uid => 1,
    );
    $calendar->add_properties(
        prodid => '//FixMyStreet//Bin Collection Calendars//EN',
        method => 'PUBLISH',
        'refresh-interval' => [ 'P1D', { value => 'DURATION' } ],
        'x-published-ttl' => 'P1D',
        calscale => 'GREGORIAN',
        'x-wr-timezone' => 'Europe/London',
        source => [ $c->uri_for_action($c->action, [ $c->stash->{uprn} ]), { value => 'URI' } ],
        url => $c->uri_for_action('waste/bin_days', [ $c->stash->{uprn} ]),
    );

    my $events = $c->cobrand->bin_future_collections;
    my $stamp = DateTime->now->strftime('%Y%m%dT%H%M%SZ');
    foreach (@$events) {
        my $event = Data::ICal::Entry::Event->new;
        $event->add_properties(
            summary => $_->{summary},
            description => $_->{desc},
            dtstamp => $stamp,
            dtstart => [ $_->{date}->ymd(''), { value => 'DATE' } ],
            dtend => [ $_->{date}->add(days=>1)->ymd(''), { value => 'DATE' } ],
        );
        $calendar->add_entry($event);
    }

    $c->res->body($calendar->as_string);
}

sub construct_bin_request_form {
    my $c = shift;

    my $field_list = [];

    foreach (@{$c->stash->{service_data}}) {
        next unless $_->{next} && !$_->{request_open};
        my $name = $_->{service_name};
        my $containers = $_->{request_containers};
        my $max = $_->{request_max};
        foreach my $id (@$containers) {
            push @$field_list, "container-$id" => {
                type => 'Checkbox',
                apply => [
                    {
                        when => { "quantity-$id" => sub { $_[0] > 0 } },
                        check => qr/^1$/,
                        message => 'Please tick the box',
                    },
                ],
                label => $name,
                option_label => $c->stash->{containers}->{$id},
                tags => { toggle => "form-quantity-$id-row" },
            };
            $name = ''; # Only on first container
            push @$field_list, "quantity-$id" => {
                type => 'Select',
                label => 'Quantity',
                tags => {
                    hint => "You can request a maximum of " . NUMWORDS($max) . " containers",
                    initial_hidden => 1,
                },
                options => [
                    { value => "", label => '-' },
                    map { { value => $_, label => $_ } } (1..$max),
                ],
                required_when => { "container-$id" => 1 },
            };
        }
    }

    push @$field_list, category => { type => 'Hidden', default => 'Request new container' };
    push @$field_list, submit => { type => 'Submit', value => 'Request new containers', element_attr => { class => 'govuk-button' } };

    return $field_list;
}

sub request : Chained('uprn') : Args(0) {
    my ($self, $c) = @_;

    my $field_list = construct_bin_request_form($c);

    $c->stash->{first_page} = 'request';
    $c->forward('form', [ {
        request => {
            title => 'Which containers do you need?',
            form => 'FixMyStreet::App::Form::Waste::Request',
            form_params => {
                field_list => $field_list,
            },
            next => 'about_you',
        },
        about_you => {
            title => 'About you',
            form => 'FixMyStreet::App::Form::Waste::AboutYou',
            form_params => {
                inactive => ['address_same', 'address'],
            },
            next => 'summary',
        },
        summary => {
            title => 'Submit container request',
            template => 'waste/summary_request.html',
            next => 'done'
        },
        done => {
            process => 'process_request_data',
            title => 'Container request sent',
            template => 'waste/confirmation.html',
        }
    } ] );
}

sub process_request_data : Private {
    my ($self, $c) = @_;
    my $data = $c->stash->{data};
    my @services = grep { /^container-/ && $data->{$_} } keys %$data;
    foreach (@services) {
        my ($id) = /container-(.*)/;
        my $container = $c->stash->{containers}{$id};
        my $quantity = $data->{"quantity-$id"};
        $data->{title} = "Request new $container";
        $data->{detail} = "Quantity: $quantity";
        $c->set_param('Container_Type', $id);
        $c->set_param('Quantity', $quantity);
        $c->forward('add_report') or return;
        push @{$c->stash->{report_ids}}, $c->stash->{report}->id;
    }
    return 1;
}

sub construct_bin_report_form {
    my $c = shift;

    my $field_list = [];

    foreach (@{$c->stash->{service_data}}) {
        next unless $_->{last} && $_->{report_allowed} && !$_->{report_open};
        my $id = $_->{service_id};
        my $name = $_->{service_name};
        push @$field_list, "service-$id" => {
            type => 'Checkbox',
            label => $name,
            option_label => $name,
        };
    }

    if (@$field_list) {
        push @$field_list, category => { type => 'Hidden', default => 'Report missed collection' };
        push @$field_list, submit => { type => 'Submit', value => 'Report collection as missed', element_attr => { class => 'govuk-button' } };
    }

    return $field_list;
}

sub report : Chained('uprn') : Args(0) {
    my ($self, $c) = @_;

    my $field_list = construct_bin_report_form($c);

    $c->stash->{first_page} = 'report';
    $c->forward('form', [ {
        report => {
            title => 'Select your missed collection',
            form => 'FixMyStreet::App::Form::Waste::Report',
            form_params => {
                field_list => $field_list,
            },
            next => 'about_you',
        },
        about_you => {
            title => 'About you',
            form => 'FixMyStreet::App::Form::Waste::AboutYou',
            form_params => {
                inactive => ['address_same', 'address'],
            },
            next => 'summary',
        },
        summary => {
            title => 'Submit missed collection',
            template => 'waste/summary_report.html',
            next => 'done'
        },
        done => {
            process => 'process_report_data',
            title => 'Missed collection sent',
            template => 'waste/confirmation.html',
        }
    } ] );
}

sub process_report_data : Private {
    my ($self, $c) = @_;
    my $data = $c->stash->{data};
    my @services = grep { /^service-/ && $data->{$_} } keys %$data;
    foreach (@services) {
        my ($id) = /service-(.*)/;
        my $service = $c->stash->{services}{$id}{service_name};
        $data->{title} = "Report missed $service";
        $data->{detail} = $data->{title};
        $c->set_param('service_id', $id);
        $c->forward('add_report') or return;
        push @{$c->stash->{report_ids}}, $c->stash->{report}->id;
    }
    return 1;
}

sub enquiry : Chained('uprn') : Args(0) {
    my ($self, $c) = @_;

    if (my $template = $c->get_param('template')) {
        $c->stash->{template} = "waste/enquiry-$template.html";
        $c->detach;
    }

    $c->forward('setup_categories_and_bodies');

    my $category = $c->get_param('category');
    my $service = $c->get_param('service_id');
    if (!$category || !$service || !$c->stash->{services}{$service}) {
        $c->res->redirect('/waste/uprn/' . $c->stash->{uprn});
        $c->detach;
    }
    my ($contact) = grep { $_->category eq $category } @{$c->stash->{contacts}};
    if (!$contact) {
        $c->res->redirect('/waste/uprn/' . $c->stash->{uprn});
        $c->detach;
    }

    my $field_list = [];
    foreach (@{$contact->get_metadata_for_input}) {
        next if $_->{code} eq 'service_id' || $_->{code} eq 'uprn';
        my $type = 'Text';
        $type = 'TextArea' if 'text' eq ($_->{datatype} || '');
        my $required = $_->{required} eq 'true' ? 1 : 0;
        push @$field_list, "extra_$_->{code}" => {
            type => $type, label => $_->{description}, required => $required
        };
    }

    push @$field_list, category => { type => 'Hidden', default => $c->get_param('category') };
    push @$field_list, service_id => { type => 'Hidden', default => $c->get_param('service_id') };
    push @$field_list, submit => { type => 'Submit', value => 'Continue', element_attr => { class => 'govuk-button' } };

    $c->stash->{first_page} = 'enquiry';
    $c->forward('form', [ {
        enquiry => {
            title => $category,
            form_params => {
                field_list => $field_list,
            },
            next => 'about_you',
        },
        about_you => {
            title => 'About you',
            form => 'FixMyStreet::App::Form::Waste::AboutYou',
            form_params => {
                inactive => ['address_same', 'address'],
            },
            next => 'summary',
        },
        summary => {
            title => 'Submit missed collection',
            template => 'waste/summary_enquiry.html',
            next => 'done'
        },
        done => {
            process => 'process_enquiry_data',
            title => 'Enquiry sent',
            template => 'waste/confirmation.html',
        }
    } ] );
}

sub process_enquiry_data : Private {
    my ($self, $c) = @_;
    my $data = $c->stash->{data};
    $data->{title} = $data->{category};
    $data->{detail} = $data->{category};
    # Read extra details in loop
    foreach (grep { /^extra_/ } keys %$data) {
        my ($id) = /^extra_(.*)/;
        $c->set_param($id, $data->{$_});
    }
    $c->set_param('service_id', $data->{service_id});
    $c->forward('add_report') or return;
    push @{$c->stash->{report_ids}}, $c->stash->{report}->id;
    return 1;
}

sub load_form {
    my ($saved_data, $page_data) = @_;
    my $form_class = $page_data->{form} || 'HTML::FormHandler';
    my $form = $form_class->new(
        init_object => $saved_data,
        %{$page_data->{form_params} || {}},
    );
    return $form;
}

sub form : Private {
    my ($self, $c, $pages) = @_;

    my $saved_data = $c->get_param('saved_data');
    $saved_data = FixMyStreet::App::Form::Field::JSON->inflate_json($saved_data) || {};
    map { $saved_data->{$_} = 1 } grep { /^(service|container)-/ && $c->req->params->{$_} } keys %{$c->req->params};

    my $goto = $c->get_param('goto') || '';
    my $process = $c->get_param('process') || '';
    $goto = $c->stash->{first_page} unless $goto || $process;
    if ( ($goto && $process) || ($goto && !$pages->{$goto}) || ($process && !$pages->{$process})) {
        $c->detach('/page_error_400_bad_request', [ 'Bad request' ]);
    }

    my $page = $goto || $process;
    my $form = load_form($saved_data, $pages->{$page});

    if ($process) {
        $c->forward('/auth/check_csrf_token');
        $form->process(params => $c->req->body_params);
        if ($form->validated) {
            $saved_data = { %$saved_data, %{$form->value} };
            $c->stash->{data} = $saved_data;
            my $next = $pages->{$page}{next};
            $form = load_form($saved_data, $pages->{$next});
            my $success = 1;
            if ($next eq 'done') {
                $success = $c->forward($pages->{$next}{process});
                if (!$success) {
                    $form->add_form_error('Something went wrong, please try again');
                    foreach (keys %{$c->stash->{field_errors}}) {
                        $form->add_form_error("$_: " . $c->stash->{field_errors}{$_});
                    }
                }
            }
            $page = $next if $success;
        }
    }

    $c->stash->{template} = $pages->{$page}{template} || 'waste/index.html';
    $c->stash->{title} = $pages->{$page}{title};
    $c->stash->{process} = $page;
    $c->stash->{saved_data} = FixMyStreet::App::Form::Field::JSON->deflate_json($saved_data);
    $c->stash->{form} = $form;
}

sub add_report : Private {
    my ( $self, $c ) = @_;

    $c->stash->{cobrand_data} = 'waste';

    my $data = $c->stash->{data};

    $c->set_param('form_as', 'another_user') if $c->user_exists && $c->user->from_body && $c->user->email ne $data->{email}; # XXX

    # Set the data as if a new report form has been submitted

    $c->set_param('submit_problem', 1);
    $c->set_param('pc', '');
    $c->set_param('non_public', 1);

    $c->set_param('name', $data->{name});
    $c->set_param('username', $data->{email} || $data->{phone});
    $c->set_param('phone', $data->{phone});

    $c->set_param('category', $data->{category});
    $c->set_param('title', $data->{title});
    $c->set_param('detail', $data->{detail});
    $c->set_param('uprn', $c->stash->{uprn});

    $c->forward('setup_categories_and_bodies') unless $c->stash->{contacts};
    $c->forward('/report/new/non_map_creation', [['/waste/remove_name_errors']]) or return;
    my $report = $c->stash->{report};
    $report->confirm;
    $report->update;
    return 1;
}

sub remove_name_errors : Private {
    my ($self, $c) = @_;
    # We do not mind about missing title/split name here
    my $field_errors = $c->stash->{field_errors};
    delete $field_errors->{fms_extra_title};
    delete $field_errors->{first_name};
    delete $field_errors->{last_name};
}

sub setup_categories_and_bodies : Private {
    my ($self, $c) = @_;

    $c->stash->{all_areas} = $c->stash->{all_areas_mapit} = { $c->cobrand->council_area_id => { id => $c->cobrand->council_area_id } };
    $c->forward('/report/new/setup_categories_and_bodies');
    my $contacts = $c->stash->{contacts};
    @$contacts = grep { grep { $_ eq 'Waste' } @{$_->groups} } @$contacts;
}

sub receive_echo_event_notification : Path('/waste/echo') : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{format} = 'xml';
    $c->response->header(Content_Type => 'text/xml');

    require SOAP::Lite;

    $c->detach('soap_error', [ 'Invalid method', 405 ]) unless $c->req->method eq 'POST';

    my $echo = $c->cobrand->feature('echo');
    $c->detach('soap_error', [ 'Missing config', 500 ]) unless $echo;

    # Make sure we log entire request for debugging
    $c->detach('soap_error', [ 'Missing body' ]) unless $c->req->body;
    my $soap = join('', $c->req->body->getlines);
    $c->log->info($soap);

    my $action = $c->req->header('SOAPAction');
    $c->log->info('SOAPAction ' . ($action || '-'));
    $c->detach('soap_error', [ 'Incorrect Action' ]) unless $action && $action eq $echo->{receive_action};

    my $body = $c->cobrand->body;
    $c->detach('soap_error', [ 'Bad jurisdiction' ]) unless $body;

    my $env = SOAP::Deserializer->deserialize($soap);

    my $header = $env->header;
    $c->detach('soap_error', [ 'Missing SOAP header' ]) unless $header;
    $header = $header->{Security};
    $c->detach('soap_error', [ 'Missing Security header' ]) unless $header;
    my $token = $header->{UsernameToken};
    $c->detach('soap_error', [ 'Authentication failed' ])
        unless $token && $token->{Username} eq $echo->{receive_username} && $token->{Password} eq $echo->{receive_password};

    my $event = $env->result;

    my $cfg = { echo => Integrations::Echo->new(%$echo) };
    my $request = $c->cobrand->construct_waste_open311_update($cfg, $event);
    $request->{updated_datetime} = DateTime::Format::W3CDTF->format_datetime(DateTime->now);
    $request->{service_request_id} = $event->{Guid};

    $c->stash->{check_existing_action} = '/waste/check_existing_update';
    $c->stash->{bad_request_action} = '/waste/soap_error';
    $c->forward('/open311/updates/process_update', [ $body, $request ]);
}

sub soap_error : Private {
    my ($self, $c, $comment, $code) = @_;
    $code ||= 400;
    $c->response->status($code);
    my $type = $code == 500 ? 'Server' : 'Client';
    $c->response->body(SOAP::Serializer->fault($type, "Bad request: $comment"));
}

sub check_existing_update : Private {
    my ($self, $c, $p, $request, $updates) = @_;

    my $cfg = { updates => $updates };
    $c->detach('soap_error', [ 'already exists' ])
        unless $c->cobrand->waste_check_last_update(
            $cfg, $p, $request->{status}, $request->{external_status_code});
}

__PACKAGE__->meta->make_immutable;

1;
