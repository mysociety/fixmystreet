# Local version to clone schema in enable_dbic_querylogging

package Catalyst::TraitFor::Model::DBIC::Schema::QueryLog::AdoptPlack;
our $VERSION = "0.07";

use 5.008004;
use Moose::Role;
use Plack::Middleware::DBIC::QueryLog;
use Scalar::Util 'blessed';

with 'Catalyst::Component::InstancePerContext';

requires 'storage';

has show_missing_ql_warning => (is=>'rw', default=>1);

sub get_querylog_from_env {
  my ($self, $env) = @_;
  return Plack::Middleware::DBIC::QueryLog->get_querylog_from_env($env);
}

sub infer_env_from {
  my ($self, $ctx) = @_;
  if($ctx->engine->can('env')) {
    return $ctx->engine->env;
  } elsif($ctx->request->can('env')) {
    return $ctx->request->env;
  } else { return }
}

sub enable_dbic_querylogging {
  my ($self, $querylog) = @_;
  my $clone = $self->clone;
  $clone->storage->debugobj($querylog);
  $clone->storage->debug(1);
}

sub die_missing_querylog {
  shift->show_missing_ql_warning(0);
  die <<DEAD;
You asked me to querylog DBIC, but there is no querylog object in the Plack
\$env. You probably forgot to enable Plack::Middleware::Debug::DBIC::QueryLog
in your debugging panel.
DEAD
}

sub die_not_plack {
  die "Not a Plack Engine or compatible interface!"
}

sub build_per_context_instance {
  my ( $self, $ctx ) = @_;
  return $self unless blessed($ctx);

  if(my $env = $self->infer_env_from($ctx)) {
    if(my $querylog = $self->get_querylog_from_env($env)) {
      $self->enable_dbic_querylogging($querylog);
    } else {
      $self->die_missing_querylog() if
        $self->show_missing_ql_warning;
    }
  } else {
    die_not_plack();
  }

  return $self;
}

1;

=head1 NAME

Catalyst::TraitFor::Model::DBIC::Schema::QueryLog::AdoptPlack - Use a Plack Middleware QueryLog

=head1 SYNOPSIS

    package MyApp::Web::Model::Schema;
    use parent 'Catalyst::Model::DBIC::Schema';

	__PACKAGE__->config({
        schema_class => 'MyApp::Schema',
        traits => ['QueryLog::AdoptPlack'],
        ## .. rest of configuration
	});

=head1 DESCRIPTION

This is a trait for L<Catalyst::Model::DBIC::Schema> which adopts a L<Plack>
created L<DBIx::Class::QueryLog> and logs SQL for a given request cycle.  It is
intended to be compatible with L<Catalyst::TraitFor::Model::DBIC::Schema::QueryLog>
which you may already be using.

It picks up the querylog from C<< $env->{'plack.middleware.dbic.querylog'} >>
or from  C<< $env->{'plack.middleware.debug.dbic.querylog'} >>  which is generally
provided by the L<Plack> middleware L<Plack::Middleware::Debug::DBIC::QueryLog>
In fact you will probably use these two modules together.  Please see the documentation
in L<Plack::Middleware::Debug::DBIC::QueryLog> for an example.

PLEASE NOTE: Starting with the 0.04 version of L<Plack::Middleware::Debug::DBIC::QueryLog>
we will canonicalize on C<< $env->{'plack.middleware.dbic.querylog'} >>.  For now
both listed keys will work, but within a release or two the older key will warn and
prompt you to upgrade your version of L<Plack::Middleware::Debug::DBIC::QueryLog>.
Sorry for the trouble.

=head1 SEE ALSO

L<Plack::Middleware::Debug::DBIC::QueryLog>,
L<Catalyst::TraitFor::Model::DBIC::Schema::QueryLog>,
L<Catalyst::Model::DBIC::Schema>,
L<Plack::Middleware::Debug>

=head1 ACKNOWLEGEMENTS

This code inspired from L<Catalyst::TraitFor::Model::DBIC::Schema::QueryLog>
and the author owes a debt of gratitude for the original authors.

=head1 AUTHOR

John Napiorkowski, C<< <jjnapiork@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2012, John Napiorkowski

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
