#!/usr/bin/env perl

use strict;
use warnings;

use inc::Module::Install;
use Module::Install::Catalyst;

name 'FixMyStreet-App';
all_from 'perllib/FixMyStreet/App.pm';

requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::Model::Adaptor';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Session::Store::DBIC';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Runtime' => '5.80031';
requires 'Catalyst::View::TT';
requires 'Config::General';
requires 'DBD::Pg' => '2.9.2';
requires 'DBIx::Class::Schema::Loader';
requires 'Email::Send';
requires 'Email::Simple';
requires 'Email::Valid';
requires 'HTML::Entities';
requires 'IO::String';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Net::Domain::TLD';
requires 'Path::Class';
requires 'Readonly';
requires 'Sort::Key';
requires 'List::MoreUtils';
requires 'IPC::Run3';
requires 'Data::UUID';
requires 'YAML';
requires 'Geography::NationalGrid';
requires 'Digest::SHA1';
requires 'XML::RSS';
requires 'Regexp::Common';
requires 'Text::Template';
requires 'Image::Size';
requires 'Image::Magick';
requires 'Statistics::Distributions';

test_requires 'Test::More' => '0.88';
test_requires 'Test::WWW::Mechanize::Catalyst';
test_requires 'Sub::Override';

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
