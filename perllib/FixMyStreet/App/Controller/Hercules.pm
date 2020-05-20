package FixMyStreet::App::Controller::Hercules;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use utf8;
use FixMyStreet::App::Form::UPRN;
use FixMyStreet::App::Form::BinRequest;
use FixMyStreet::App::Form::AboutYou;
use FixMyStreet::App::Form::Field::JSON;

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if (my $uprn = $c->get_param('address')) {
        $c->detach('redirect_to_uprn', [ $uprn ]);
    }

    $c->stash->{title} = 'What is your address?';
    my $form = FixMyStreet::App::Form::UPRN->new;
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
    my $uri = '/hercules/uprn/' . $uprn;
    my $type = $c->get_param('type') || '';
    $uri .= '/request' if $type eq 'request';
    $uri .= '/report' if $type eq 'report';
    $c->res->redirect($uri);
    $c->detach;
}

sub uprn : Chained('/') : PathPart('hercules/uprn') : CaptureArgs(1) {
    my ($self, $c, $uprn) = @_;

    if ($uprn eq 'missing') {
        $c->stash->{template} = 'hercules/missing.html';
        $c->detach;
    }

    $c->stash->{property} = FixMyStreet::Cobrand::Bromley->look_up_property($uprn);
	# Id, PointType, PointSegmentId, PointAddressType, Description, StreetId, Coordinates->GeoPoint
    $c->stash->{uprn} = $uprn;
}

sub bin_days : Chained('uprn') : PathPart('') : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{data} = FixMyStreet::Cobrand::Bromley->bin_services_for_address($c->stash->{uprn});
}

sub request : Chained('uprn') : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{first_page} = 'request';
    $c->forward('form', [ {
        request => {
            title => 'Which containers do you need?',
            form => 'FixMyStreet::App::Form::BinRequest',
            next => 'about_you',
        },
        about_you => {
            title => 'About you',
            form => 'FixMyStreet::App::Form::AboutYou',
            next => 'summary',
        },
        summary => {
            title => 'Submit container request',
            template => 'hercules/summary_request.html',
            next => 'done'
        },
        done => {
            title => 'Container request sent',
            template => 'hercules/confirmation.html',
        }
    } ] );
}

sub report : Chained('uprn') : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{first_page} = 'report';
    $c->forward('form', [ {
        report => {
            title => 'Select your missed collection',
            form_params => {
                field_list => [
                    refuse123 => { type => 'Checkbox', label => 'Refuse', option_label => 'Refuse' },
                    recycling123 => { type => 'Checkbox', label => 'Mixed recycling', option_label => 'Mixed recycling' },
                    submit => { type => 'Submit', value => 'Report collection as missed', element_attr => { class => 'govuk-button' } },
                ],
            },
            next => 'about_you',
        },
        about_you => {
            title => 'About you',
            form => 'FixMyStreet::App::Form::AboutYou',
            form_params => {
                inactive => ['address_same', 'address'],
            },
            next => 'summary',
        },
        summary => {
            title => 'Submit missed collection',
            template => 'hercules/summary_report.html',
            next => 'done'
        },
        done => {
            title => 'Missed collection sent',
            template => 'hercules/confirmation.html',
        }
    } ] );
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

    $c->forward('/auth/get_csrf_token');

    my $goto = $c->get_param('goto') || '';
    my $process = $c->get_param('process') || '';
    $goto = $c->stash->{first_page} unless $goto || $process;
    if ( ($goto && $process) || ($goto && !$pages->{$goto}) || ($process && !$pages->{$process})) {
        $c->detach('/page_error_400_bad_request', [ 'Bad request' ]);
    }

    my $page = $goto || $process;
    my $form = load_form($saved_data, $pages->{$page});

    if ($process) {
        $form->process(params => $c->req->body_params);
        if ($form->validated) {
			$saved_data = { %$saved_data, %{$form->value} };
            $c->stash->{data} = $saved_data;
            $page = $pages->{$page}{next};
            $form = load_form($saved_data, $pages->{$page});
			if ($page eq 'done') {
				$c->forward('add_report');
			}
        }
	}

    $c->stash->{template} = $pages->{$page}{template} || 'hercules/index.html';
    $c->stash->{title} = $pages->{$page}{title};
    $c->stash->{process} = $page;
    $c->stash->{saved_data} = FixMyStreet::App::Form::Field::JSON->deflate_json($saved_data);
    $c->stash->{form} = $form;
}

sub add_report : Private {
    my ( $self, $c ) = @_;

	my $data = $c->stash->{data};

    $c->set_param('non_public', 1);
    $c->set_param('latitude', 0);
    $c->set_param('longitude', 0);
	$c->set_param('submit_problem', 1);
	$c->set_param('name', $data->{name});
	$c->set_param('username', $data->{email});
	$c->set_param('phone', $data->{phone});

	$c->set_param('title', '');
	$c->set_param('detail', '');
	$c->set_param('category', '');
    # needs contacts, missing_details_bodies on stash

    #$c->forward('/report/new/initialize_report');
    #$c->forward('/report/new/check_for_category');
    #$c->forward('/auth/check_csrf_token');
    #$c->forward('/report/new/process_report');
    #$c->forward('/report/new/process_user');
    #$c->forward('/photo/process_photo');
    #$c->detach unless $c->forward('/report/new/check_for_errors');
    #$c->forward('/report/new/save_user_and_report');
    #$c->forward('confirm_report');
}

sub confirm_report {
    my ( $self, $c ) = @_;

    my $report = $c->stash->{report};
    $report->confirm;
    $report->update;
}

=item

 ** Uses a cobrand fn to set up bodies/contacts/missing_details stuff

 1. initialize_report               Web     Mobile      Enquiry     Hercules
 2. /auth/get_csrf_token            Web                 Enquiry     Hercules
 3. setup_categories_and_bodies     Web     Mobile		**			?
 4. setup_report_extra_fields       Web     Mobile
 5. check_for_category              Web     Mobile      Enquiry     Hercules
 6. setup_report_extras             Web (only for templates)
 7. /auth/check_csrf_token          Web                 Enquiry     Hercules
 8. process_report                  Web     Mobile      Enquiry     Hercules
 9. process_user                    Web     Mobile      Enquiry     Hercules
10. handle_uploads                                      Enquiry
11. /photo/process_photo            Web     Mobile      Enquiry
12. check_for_errors && detach      Web     Mobile      Enquiry     Hercules
13. save_user_and_report            Web     Mobile      Enquiry     Hercules
14. FINAL STEP DIFFERS              Web     Mobile      Enquiry     Hercules

=cut

__PACKAGE__->meta->make_immutable;

1;
