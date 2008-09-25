#!/usr/bin/perl
use warnings;
use strict;

use lib 'lib';
use Socialtext::SQL qw/get_dbh/;
use List::Util qw(shuffle);

my $dbh = get_dbh();
$| = 1;

$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 0;
$dbh->rollback;
$dbh->begin_work;

$dbh->{RaiseError} = 1;

my $ACCOUNTS = 10_000;
my $USERS = 20_000; # _Must_ be bigger than $ACCOUNTS
my $PAGES = 10_000;
my $MAX_WS_ASSIGN = 50;
my $PAGE_VIEW_EVENTS = 90_000;
my $OTHER_EVENTS = 10_000;

my @accounts;
my @workspaces;
my @users;
my %ws_to_acct;
my @pages;

print "Creating $ACCOUNTS accounts with $ACCOUNTS workspaces...";

foreach my $i (1 .. $ACCOUNTS) {
    my $acct_sth = $dbh->prepare_cached(qq{
        INSERT INTO "Account" (account_id, name)
        VALUES (nextval('"Account___account_id"'), ?)
    });
    my $ws_sth = $dbh->prepare_cached(qq{
        INSERT INTO "Workspace" (
            workspace_id, name, title, 
            account_id, created_by_user_id, skin_name
        ) VALUES (
            nextval('"Workspace___workspace_id"'), ?, ?,
            currval('"Account___account_id"'), 1, 's3'
        )
    });

    $acct_sth->execute("Test Account $i");
    $ws_sth->execute("test_workspace_$i", "Test Workspace $i");
    
    my ($acct_id) = $dbh->selectrow_array(q{SELECT currval('"Account___account_id"')});
    push @accounts, $acct_id;
    my ($ws_id) = $dbh->selectrow_array(q{SELECT currval('"Workspace___workspace_id"')});
    push @workspaces, $ws_id;
    $ws_to_acct{$ws_id} = $acct_id;
}

print "done\n";

print "enable people & dashboard for 5% of the accounts...";
my $pd_enabled = int(@accounts * 0.05);
foreach my $acct_id (@accounts[0 .. $pd_enabled]) {

    my $pd_sth = $dbh->prepare_cached(qq{
        INSERT INTO account_plugin (
            account_id, plugin
        ) VALUES (
            ?, ?
        )
    });

    for my $plugin ( 'people', 'dashboard', 'widgets' ) {
        $pd_sth->execute( $acct_id, $plugin );
    }
}
print "done\n";

my $n = $ACCOUNTS;
my $m = $n;
my $name = $ACCOUNTS;
my %rand_accounts = map {$_=>1} @accounts;

print "Assigning $ACCOUNTS more workspaces to random accounts (geometric dist.)...";
while ($n > 0) {
    $m = int($n / 2.0);
    $m = 1 if $m <= 0;

    # pick an account at random
    # assign M workspaces to it
    my $acct_id = (keys %rand_accounts)[0];
    delete $rand_accounts{$acct_id};

    for (my $j=0; $j<$m; $j++) {
        $name++;
        my $ws_sth = $dbh->prepare_cached(qq{
            INSERT INTO "Workspace" (
                workspace_id, name, title, 
                account_id, created_by_user_id, skin_name
            ) VALUES (
                nextval('"Workspace___workspace_id"'), ?, ?,
                ?, 1, 's3'
            )
        });
        $ws_sth->execute("test_workspace_$name", "Test Workspace $name", $acct_id);
        my ($ws_id) = $dbh->selectrow_array(q{SELECT currval('"Workspace___workspace_id"')});
        push @workspaces, $ws_id;
        $ws_to_acct{$ws_id} = $acct_id;
    }

    $n -= $m;
}
print "done\n";

print "Adding $USERS users ...";

my $user_id;
foreach my $user ( 1 .. $USERS ) {
    my $user_id_sth = $dbh->prepare_cached(qq{
       INSERT INTO "UserId" (
           system_unique_id, driver_key, driver_unique_id, driver_username
       ) VALUES (
           nextval('"UserId___system_unique_id"'), ?,
           currval('"UserId___system_unique_id"'), ?
       )
    });

    $user_id_sth->execute('Default', "user_$user");
    ($user_id) = $dbh->selectrow_array(q{SELECT currval('"UserId___system_unique_id"')});

    my $user_sth = $dbh->prepare_cached(qq{
        INSERT INTO "User" (
            user_id, username, email_address, password, first_name, last_name
        ) VALUES (
            ?, ?, ?, ?, ?, ?
        )
    });

    $user_sth->execute( $user_id, "User_$user_id", "user-$user_id\@example.com", 'password', "First$user_id", "Last$user_id" );

    my $user_meta_sth = $dbh->prepare_cached(qq{
        INSERT INTO "UserMetadata" (
           user_id, email_address_at_import, 
           created_by_user_id, primary_account_id
        ) VALUES (
           ?, ?, NULL, 1
        )
    });

    $user_meta_sth->execute( $user_id, "user-$user_id\@example.com" );
    push @users, $user_id;
}
print "done\n";

print "Assigning users to accounts and workspaces...";

# assigns half of the users to some number of workspaces
my %rand_users = map { $_ => 1 } @users;
for ( 1 .. $USERS/2) {

    $m = int(rand($MAX_WS_ASSIGN))+1;
    my $user_id = (keys %rand_users)[0];
    delete $rand_users{$user_id};
    assign_random_workspaces($user_id, $m, \@workspaces); 
}

sub assign_random_workspaces 
{
    my ($user_id, $number, $workspaces) = @_;
    my @workspaces = shuffle @$workspaces;

    my $primary_ws = $workspaces[1];
    # set the user's account to the same account as this ws
    my $updt_sth = $dbh->prepare_cached(q{
        UPDATE "UserMetadata"
        SET primary_account_id = ?
        WHERE user_id = ?
    });
    $updt_sth->execute($ws_to_acct{$primary_ws}, $user_id);

    for (1 .. $number) {
        my $ws_id = $workspaces[$_];
        # assign a user to a workspace
        my $assign_sth = $dbh->prepare_cached(q{
            INSERT INTO "UserWorkspaceRole" (user_id, workspace_id, role_id)
            VALUES (?, ?, 3)
        });
        $assign_sth->execute($user_id, $ws_id);
    }

}
print "done.\n";

print "CHECK >>> users with the default account: ";
print $dbh->selectrow_array('select count(*) from "UserMetadata" where primary_account_id = 1');
print "\n";

my $create_ts = '2007-01-01 00:00:00+0000';
print "creating $PAGES pages...";
foreach my $p (1 .. $PAGES) {
    my $page_sth = $dbh->prepare_cached(q{
        INSERT INTO page (
            workspace_id, page_id, name, 
            last_editor_id, creator_id,
            last_edit_time, create_time,
            current_revision_id, current_revision_num, revision_count,
            page_type, deleted, summary
        ) VALUES (
            ?, ?, ?,
            ?, ?,
            ?::timestamptz + ?::interval, ?::timestamptz,
            ?, 1, 1,
            'wiki', 'f', 'summary'
        )
    });

    my $ws = $workspaces[int(rand(scalar @workspaces))];
    my $editor = $users[int(rand(scalar @users))];
    my $creator = $users[int(rand(scalar @users))];
    my $page_id = "page_$p";
    $page_sth->execute(
        $ws, $page_id, "Page: $p!",
        $editor, $creator,
        $create_ts, rand(int($PAGES)).' seconds', $create_ts,
        '20070101000000',
    );
    push @pages, [$ws, $page_id];
}
print "done.\n";

print "generating page view events...";
foreach (1 .. $PAGE_VIEW_EVENTS) {
    my $ev_sth = $dbh->prepare_cached(q{
        INSERT INTO event (
            at, event_class, action, 
            actor_id, page_workspace_id, page_id
        ) VALUES (
            ?::timestamptz + ?::interval, 'page', 'view', 
            ?, ?, ?
        )
    });
    my $actor = $users[int(rand(scalar @users))];
    my $page = $pages[int(rand(scalar @pages))];
    $ev_sth->execute(
        $create_ts, rand(int($PAGES)).' seconds', 
        $actor, $page->[0], $page->[1]
    );
}
print "done.\n";

print "generating other events...";
foreach (1 .. $OTHER_EVENTS) {
    my $ev_sth = $dbh->prepare_cached(q{
        INSERT INTO event (
            at, 
            event_class, action, 
            actor_id, person_id, page_workspace_id, page_id
        ) VALUES (
            ?::timestamptz + ?::interval,
            ?, ?, 
            ?, ?, ?, ?
        )
    });
    my $actor = $users[int(rand(scalar @users))];
    my $page = [undef,undef];
    my $person = undef;
    my @actions;

    my @classes = (('page') x 8, 'person');
    my $class = $classes[int(rand(scalar @classes))];
    if ($class eq 'page') {
        my $page = $pages[int(rand(scalar @pages))];
        @actions = qw(tag_add watch_add watch_delete rename edit_save comment duplicate edit_contention delete);
    }
    else {
        my $person = $users[int(rand(scalar @users))];
        @actions = qw(tag_add watch_add tag_delete watch_delete edit_save);
    }
    my $action = $actions[int(rand(scalar @actions))];

    $ev_sth->execute(
        $create_ts, rand(int($PAGES)).' seconds', 
        $class, $action,
        $actor, $person, $page->[0], $page->[1]
    );
}
print "done.\n";

print "CHECK >>> page events: ";
print $dbh->selectrow_array(q{select count(*) from event where event_class = 'page'});
print "\n";

print "CHECK >>> person events: ";
print $dbh->selectrow_array(q{select count(*) from event where event_class = 'person'});
print "\n";

# * 10,000,000 Events
# ** 9,000,000 `page:view` events
# ** 800,000 other page events
# ** remainder as people events

# page tags?
# people tags?

# page watchlists
# people watchlists

$dbh->commit;
print "ALL DONE!\n";
