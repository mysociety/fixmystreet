=head1 NAME

FixMyStreet::Script::CSVExport - pre-generate CSV files for quicker dashboard export

=head1 SYNOPSIS

This script can be used to fetch all reports for a cobrand/body, along with any
additional data required, outputting to disk to then be used by the front end
CSV dashboard export.

=head1 DESCRIPTION

=cut

package FixMyStreet::Script::CSVExport;

use v5.14;
use warnings;
use DBI;
use JSON::MaybeXS;
use Path::Tiny;
use Text::CSV;
use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use FixMyStreet::Reporting;
use Utils;

=head2 Cobrand variations

The database query speed does not vary that much with extra joins/CTEs,
but it seemed clearer to list particular uses by individual cobrands.

staff_user (the contributed_by's email) and staff_role (their roles) are always
fetched (so that the role filter in the front end works); to use them they only
need adding in the cobrand with add_csv_columns.

=over 4

=item user_details - fetch the report `user_email` and `user_phone`

=item assigned_to - include the name of the assigned user in `assigned_to`

=item db_state - store the actual database state name (if the state column is changed by the cobrand)

=item reassigned - include reassigned_at and ressigned_by for an admin category change

=item comment_content - the actual content of updates

=back

=cut

my $EXTRAS = {
    reassigned => { tfl => 1 },
    assigned_to => { northumberland => 1, tfl => 1 },
    staff_user => { bathnes => 1, bromley => 1, buckinghamshire => 1, northumberland => 1, peterborough => 1 },
    staff_roles => { bromley => 1, northumberland => 1, brent => 1 },
    user_details => { bathnes => 1, bexley => 1, brent => 1, camden => 1, cyclinguk => 1, highwaysengland => 1, kingston => 1, sutton => 1 },
    comment_content => { highwaysengland => 1 },
    db_state => { peterborough => 1 },
    alerts_count => { surrey => 1 },
};

my $fixed_states = FixMyStreet::DB::Result::Problem->fixed_states;
my $closed_states = FixMyStreet::DB::Result::Problem->closed_states;
my $JSON = JSON::MaybeXS->new->allow_nonref;

=head2 process

Processes all bodies with a cobrand

=cut

sub process {
    my %opts = @_;
    $opts{dbh} ||= do {
        my @args = FixMyStreet->dbic_connect_info;
        $args[3]{RaiseError} = 1;
        DBI->connect(@args[0..3]) or die $!;
    };
    if ($opts{body}) {
        process_body($opts{body}, \%opts);
    } else {
        my $bodies = $opts{dbh}->selectcol_arrayref("select id from body where extra->>'cobrand' !='' order by id");
        process_body($_, \%opts) foreach @$bodies;
    }
}

=head2 process_body

Given a body ID, queries the database for all its reports
and outputs as CSV to a file.

=cut

sub process_body {
    my ($body_id, $opts) = @_;
    my $dbh = $opts->{dbh};

    my $body = FixMyStreet::DB->resultset("Body")->find($body_id);
    print "Processing " . $body->name . "\n" if $opts->{verbose};
    my $start = time();
    my $cobrand = $body->get_cobrand_handler;
    return unless $cobrand;
    FixMyStreet::DB->schema->cobrand($cobrand);

    my $reporting = FixMyStreet::Reporting->new(
        type => 'problems',
        body => $body,
        user => $body->comment_user,
        dbi => 1, # Flag we are doing it via DBI
    );
    $reporting->construct_rs_filter; # So it exists
    $reporting->csv_parameters;
    $reporting->splice_csv_column('id', areas => 'Areas');
    $reporting->splice_csv_column('id', roles => 'Roles');
    if ($EXTRAS->{db_state}{$cobrand->moniker}) {
        $reporting->splice_csv_column('id', db_state => 'DBState');
    }

    my $out = $reporting->premade_csv_filename;
    my $file = path("$out-part");
    my $handle = $file->openw_utf8;
    my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
    $csv->print($handle, $reporting->csv_headers);

    my $children = $body->area_children(1);

    my $sql = generate_sql($body_id, $cobrand);
    $dbh->do($sql) or die $dbh->errstr;

    my $hashref;
    while (1) {
        my $sth = $dbh->prepare("FETCH 1000 FROM csr");
        $sth->execute;
        last if 0 == $sth->rows;
        while (my $obj = $sth->fetchrow_hashref) {
            my $extra = $JSON->decode($obj->{extra} || '{}');
            if (ref $extra eq 'ARRAY') { $extra = { _fields => $extra }; }
            $obj->{extra} = $extra;
            foreach (@{$obj->{extra}{_fields}}) {
                $obj->{extra}{_field_value}{$_->{name}} //= $_->{value};
            }

            if (!$hashref || $hashref->{id} != $obj->{id}) {
                output($reporting, $csv, $handle, $hashref);
                $hashref = initial_hashref($obj, $cobrand, $children);
            }
            process_comment($hashref, $obj);
            process_questionnaire($hashref, $obj);
            if (my $fn = $reporting->csv_extra_data) {
                my $extra = $fn->($obj, $hashref);
                $hashref = { %$hashref, %$extra };
            }
        }
    }
    output($reporting, $csv, $handle, $hashref);
    $dbh->do("CLOSE csr");
    my $sec = time() - $start;
    print "Processed " . $body->name . " in $sec seconds\n" if $opts->{verbose};
    $file->move($out);
}

=head2 generate_sql

Generates the SQL to be fed to the database to export the relevant data.

=cut

sub generate_sql {
    my ($body_id, $cobrand) = @_;

    my @sql_select = (
        '"me".*',
        # (Override timestamps to truncate to the second)
        "to_json(date_trunc('second', me.created))#>>'{}' as created",
        "to_json(date_trunc('second', me.confirmed))#>>'{}' as confirmed",
        "to_json(date_trunc('second', me.whensent))#>>'{}' as whensent",
        # Fetch the relevant bits of comments and questionnaires we need for timestamps
        "comments.id as comment_id, comments.problem_state, to_json(date_trunc('second', comments.confirmed))#>>'{}' as comment_confirmed, comments.mark_fixed",
        "questionnaire.id as questionnaire_id, questionnaire.new_state as questionnaire_new_state",
        "to_json(date_trunc('second', questionnaire.whenanswered))#>>'{}' as questionnaire_whenanswered",
        # Older reports did not store the group on the report, so fetch it from contacts
        "contact.extra->'group' AS group",
        # Fetch any relevant staff user and their roles
        "contributed_by_user.email AS staff_user",
        "staff_roles.role_ids AS roles", "staff_roles.role_names AS staff_role",
    );
    # Use a CTE to prefetch the staff roles
    my @sql_with = (<<EOF);
staff_roles AS (
    SELECT users.id AS user_id,
        string_agg(roles.id::text, ',' order by roles.id) AS role_ids,
        string_agg(roles.name, ',' order by roles.name) AS role_names
    FROM user_roles, users, roles
    WHERE user_roles.user_id = users.id AND user_roles.role_id = roles.id AND from_body = $body_id
    GROUP BY users.id
)
EOF
    my @sql_join = (
        '"contacts" "contact" ON CAST( "contact"."body_id" AS text ) = (regexp_split_to_array( "me"."bodies_str", \',\'))[1] AND "contact"."category" = "me"."category"',
        '"comment" "comments" ON "comments"."problem_id" = "me"."id" AND "comments"."state" = \'confirmed\'',
        '"users" "contributed_by_user" ON "contributed_by_user"."id" = ("me"."extra"->>\'contributed_by\')::integer',
        'staff_roles ON contributed_by_user.id = staff_roles.user_id',
        'questionnaire ON questionnaire.problem_id = me.id AND questionnaire.whenanswered IS NOT NULL',
    );

    if ($EXTRAS->{reassigned}{$cobrand->moniker}) {
        push @sql_select, "to_json(date_trunc('second', ranked_admin_log.whenedited))#>>'{}' as reassigned_at", "admin_log_user.name as reassigned_by";
        push @sql_with, <<EOF;
ranked_admin_log AS (
    select *,row_number() over (partition by object_id order by whenedited desc) as rn from admin_log where admin_log.object_type = 'problem' AND admin_log.action = 'category_change'
)
EOF
        push @sql_join, 'ranked_admin_log ON ranked_admin_log.object_id = me.id AND rn = 1';
        push @sql_join, 'users admin_log_user ON ranked_admin_log.user_id = admin_log_user.id';
    }
    if ($EXTRAS->{assigned_to}{$cobrand->moniker}) {
        push @sql_select, "planned_user.name as assigned_to";
        push @sql_join, '"user_planned_reports" ON "user_planned_reports"."report_id" = "me"."id" AND "user_planned_reports"."removed" IS NULL';
        push @sql_join, '"users" "planned_user" ON "planned_user"."id" = "user_planned_reports"."user_id"';
    }

    if ($EXTRAS->{user_details}{$cobrand->moniker}) {
        push @sql_select, "problem_user.email AS user_email", "problem_user.phone AS user_phone";
        push @sql_join, '"users" "problem_user" ON "problem_user"."id" = "me"."user_id"';
    }
    if ($EXTRAS->{comment_content}{$cobrand->moniker}) {
        push @sql_select, "comments.text as comment_text", "comments.extra as comment_extra", "comment_user.name as comment_name", "row_number() over (partition by comments.problem_id order by comments.confirmed,comments.id) as comment_rn";
        push @sql_join, '"users" "comment_user" ON "comments"."user_id" = "comment_user"."id"';
    }
    if ($EXTRAS->{alerts_count}{$cobrand->moniker}) {
        push @sql_select, '"alerts_table"."alerts_count"';
        push @sql_join, '"alerts_table" ON CAST("alerts_table"."parameter" AS INTEGER) = "me"."id"';
        push @sql_with, "alerts_table AS (select parameter, count(*) AS alerts_count FROM alert WHERE alert_type='new_updates' AND confirmed IS NOT NULL AND whendisabled IS NULL GROUP BY 1)";
    }

    my $sql_select = join(', ', @sql_select);
    my $sql_join = join(' ', map { "LEFT JOIN $_" } @sql_join);
    my $sql_with = @sql_with ? "WITH " . join(', ', @sql_with) : '';

    my $where_states = '';
    my $all_states = $cobrand->call_hook('dashboard_export_include_all_states');
    unless ($all_states) {
        my $states = join(', ', map { "'$_'" } FixMyStreet::DB::Result::Problem->visible_states);
        $where_states = " AND me.state IN ($states)";
    }
    return <<EOF;
DECLARE csr CURSOR WITH HOLD FOR $sql_with SELECT $sql_select FROM "problem" "me" $sql_join
WHERE regexp_split_to_array("me"."bodies_str", ',') && ARRAY['$body_id']
    $where_states
ORDER BY "me"."confirmed", "me"."id", "comments"."confirmed", "comments"."id", "questionnaire"."whenanswered", "questionnaire"."id";
EOF
}

=head2 output

Given a hashref of data, outputs the csv_column keys
from it as CSV data to the filehandle.

=cut

sub output {
    my ($reporting, $csv, $handle, $hashref) = @_;
    $csv->print($handle, [ @{$hashref}{ @{$reporting->csv_columns} } ] ) if $hashref;
}

=head2 initial_hashref

As well as all the data returned by the database, add some extra default data
extracted solely from the report, including local co-ordinates, URL, ward name.

=cut

sub initial_hashref {
    my ($obj, $cobrand, $children) = @_;

    my ($x, $y) = Utils::convert_latlon_to_en( $obj->{latitude}, $obj->{longitude}, "G" ); # Adjust if ever NI

    my $hashref = {
        %$obj,
        user_name_display => $obj->{anonymous} ? '(anonymous)' : $obj->{name},
        local_coords_x => $x,
        local_coords_y => $y,
        url => $cobrand->base_url . "/report/" . $obj->{id},
        device_type => $obj->{service} || 'website',
        reported_as => $obj->{extra}->{contributed_as} || '',
        wards => join ', ', map { $children->{$_}->{name} } grep { $children->{$_} } split ',', $obj->{areas},
    };

    my $group = $obj->{extra}->{group} || $JSON->decode($obj->{group} || '[]') || [];
    $group = [ $group ] unless ref $group eq 'ARRAY';
    $group = join(',', @$group);
    if ($group) {
        $hashref->{subcategory} = $obj->{category};
        $hashref->{category} = $group;
    }

    return $hashref;
}

=head2 process_comment

Given a result row, look at the comment entries to see if we need to set any
row timestamps.

=cut

sub process_comment {
    my ($hashref, $obj) = @_;
    return if $hashref->{closed}; # Once closed is set, ignore further more comments
    return unless $obj->{problem_state} || $obj->{mark_fixed};
    my $problem_state = $obj->{problem_state} || '';
    return if $problem_state eq 'confirmed';
    $hashref->{acknowledged} //= $obj->{comment_confirmed};
    $hashref->{action_scheduled} //= $problem_state eq 'action scheduled' ? $obj->{comment_confirmed} : undef;
    if ($fixed_states->{ $problem_state } || $obj->{mark_fixed}) {
        if (!$hashref->{fixed} || $obj->{comment_confirmed} lt $hashref->{fixed}) {
            $hashref->{fixed} = $obj->{comment_confirmed};
        }
    }
    if ($closed_states->{ $problem_state }) {
        $hashref->{closed} = $obj->{comment_confirmed};
    }
}


=head2 process_questionnaire

Given a result row, look at the questionnaire entry to see if we need to set any
row timestamps.

=cut

sub process_questionnaire {
    my ($hashref, $obj) = @_;
    my $new_state = $obj->{questionnaire_new_state} || '';
    if ($fixed_states->{$new_state}) {
        if (!$hashref->{fixed} || $obj->{questionnaire_whenanswered} lt $hashref->{fixed}) {
            $hashref->{fixed} = $obj->{questionnaire_whenanswered};
        }
    }
}

1;
