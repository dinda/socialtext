package Socialtext::WebHooks;
use strict;
use warnings;
use Socialtext::Workspace;
use Socialtext::SQL qw/sql_execute sql_singlevalue/;
use Socialtext::SQL::Builder qw/sql_nextval/;
use Carp qw/croak/;
use Socialtext::Page;
use Socialtext::l10n qw/loc/;

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
    croak "No URL defined - it is mandatory!" unless $opts{url};
    croak 'URL must be HTTP or HTTPS' unless $opts{url} =~ m#^https?://#;

    my $workspace_id = $opts{workspace} ? $opts{workspace}->workspace_id 
                                        : undef;
    my $page_id = undef;
    if (my $name = $opts{page_id}) {
        my $page = Socialtext::Page->new;
        $page_id = $page->name_to_id($name);
    }

    sql_execute('INSERT INTO webhook VALUES (?, ?, ?, ?, ?)',
        sql_nextval('webhook___webhook_id'),
        $workspace_id,
        $opts{action},
        $page_id,
        $opts{url},
    );
}

sub Delete {
    my $class = shift;
    my $id    = shift;

    # ignore errors
    eval { sql_execute('DELETE FROM webhook WHERE id = ?', $id) };
}

1;
