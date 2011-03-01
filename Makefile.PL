#!/usr/bin/env perl

use strict;
use warnings;

use inc::Module::Install;
use Module::Install::Catalyst;

name 'FixMyStreet-App';
all_from 'perllib/FixMyStreet/App.pm';

requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Session::Store::DBIC';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Runtime' => '5.80031';
requires 'Config::General';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Path::Class';
requires 'Readonly';

test_requires 'Test::More' => '0.88';
test_requires 'Test::WWW::Mechanize::Catalyst';
test_requires 'Sub::Override';

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
