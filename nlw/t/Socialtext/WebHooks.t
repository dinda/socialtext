#!/usr/bin/perl
use strict;
use warnings;
use Test::Socialtext tests => 43;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::Workspace;

fixtures 'admin_no_pages';

BEGIN {
    use_ok 'Socialtext::WebHooks';
}

my $wksp = Socialtext::Workspace->new(name => 'admin');
my $hook_url = 'http://test-url';

No_webhooks: {
    Socialtext::WebHooks->Clear($wksp);
    is_deeply(Socialtext::WebHooks->All($wksp), [], 'no webhooks to start');
}

Add_webhooks: {
    my @valid_actions = qw/comment delete edit_save tag_add tag_delete/;
    for my $action (@valid_actions) {
        Socialtext::WebHooks->Add(
            action => $action,
            workspace => $wksp,
            url => $hook_url,
        );
        Socialtext::WebHooks->Add(
            action => $action,
            workspace => $wksp,
            page_id => "Admin Wiki",
            url => $hook_url,
        );
    }

    my $hooks = Socialtext::WebHooks->All($wksp);
    is scalar(@$hooks), scalar(@valid_actions)*2, 'webhooks were added';

    for my $action (@valid_actions) {
        my $h = shift @$hooks;
        is $h->{action}, $action;
        is $h->{workspace_id}, $wksp->workspace_id;
        is $h->{page_id}, undef;
        is $h->{url}, $hook_url;

        $h = shift @$hooks;
        is $h->{action}, $action;
        is $h->{workspace_id}, $wksp->workspace_id;
        is $h->{page_id}, 'admin_wiki', 'page_id is normalized';
        is $h->{url}, $hook_url;
    }
}
