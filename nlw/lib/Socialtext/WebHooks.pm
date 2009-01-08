package Socialtext::WebHooks;
use strict;
use warnings;
use Socialtext::Workspace;
use Socialtext::SQL qw/sql_execute sql_singlevalue/;
use Socialtext::SQL::Builder qw/sql_nextval/;
use Carp qw/croak/;
use Socialtext::Page;

sub Clear {
    my $class = shift;
    my $workspace = shift or croak "Workspace is mandatory!";

    sql_execute(<<EOT, $workspace->workspace_id);
DELETE FROM webhook
    WHERE workspace_id = ?
EOT
}

sub All {
    my $class = shift;
    my $workspace = shift or croak "Workspace is mandatory!";

    my $sth = sql_execute(<<EOT, $workspace->workspace_id);
SELECT * FROM webhook
    WHERE workspace_id = ?
    ORDER BY id
EOT
    return $sth->fetchall_arrayref({});
}

our %Valid_action = map { $_ => 1 } 
                    qw/comment delete edit_save tag_add tag_delete/;

sub Add {
    my $class = shift;
    my %opts = @_;
    croak 'action is not defined!' unless $opts{action};
    croak "invalid action ($opts{action})" unless $Valid_action{$opts{action}};

    my $workspace_id = $opts{workspace} ? $opts{workspace}->workspace_id 
                                        : undef;
    my $page_id = undef;
    if (my $name = $opts{page_id}) {
        my $page = Socialtext::Page->new;
        $page_id = $page->name_to_id($name);
    }

    Check_for_duplicates: {
        my $page_filter = $page_id ? 'AND page_id = ?' : 'AND page_id IS NULL';
        my $count = sql_singlevalue(<<EOT,
SELECT count(*) FROM webhook
    WHERE workspace_id = ?
      AND action = ?
      $page_filter
EOT
            $workspace_id, $opts{action}, $page_id ? ($page_id): (),
        );
        croak loc("WebHook already exists for this workspace and action.")
            if $count;
    }

    sql_execute('INSERT INTO webhook VALUES (?, ?, ?, ?)',
        sql_nextval('webhook___webhook_id'),
        $workspace_id,
        $opts{action},
        $page_id,
    );
}

1;
