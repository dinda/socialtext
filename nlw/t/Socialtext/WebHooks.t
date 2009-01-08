#!/usr/bin/perl
use strict;
use warnings;
use mocked 'LWP::UserAgent';
use Test::Socialtext tests => 49;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::Workspace;
use Socialtext::Events::Recorder;
use Socialtext::JSON qw/decode_json/;

fixtures 'admin';

BEGIN {
    use_ok 'Socialtext::WebHooks';
    use_ok 'Socialtext::Schwartz', qw/list_jobs clear_jobs client/;
}

my $wksp     = Socialtext::Workspace->new(name => 'admin');
my $hook_url = 'http://topaz.socialtext.net/~lukec/webhook.cgi';

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
        Socialtext::WebHooks->Delete($h->{id});

        $h = shift @$hooks;
        is $h->{action}, $action;
        is $h->{workspace_id}, $wksp->workspace_id;
        is $h->{page_id}, 'admin_wiki', 'page_id is normalized';
        is $h->{url}, $hook_url;
    }

    $hooks = Socialtext::WebHooks->All($wksp->workspace_id);
    is scalar(@$hooks), scalar(@valid_actions), 'half the webhooks were deleted';
}

Trigger_a_webhook: {
    Socialtext::WebHooks->Clear($wksp);
    clear_jobs();

    Socialtext::WebHooks->Add(
        action => 'comment',
        workspace => $wksp,
        url => $hook_url,
    );

    my $erec = Socialtext::Events::Recorder->new;
    my $event = {
        event_class => 'page',
        action => 'comment',
        actor => 1,
        person => 1,
        page => 'admin_wiki',
        workspace => $wksp->workspace_id,
    };
    $erec->record_event( $event );

    my @jobs = list_jobs( 
        funcname => 'WebHook',
    );
    is scalar(@jobs), 1, 'found a webhook job';

    # Process the jobs
    $LWP::UserAgent::RESULTS{$hook_url} = 200;
    my $client = client();
    $client->can_do('Socialtext::Job::WebHook');
    $client->work_once;

    @jobs = list_jobs( 
        funcname => 'WebHook',
    );
    is scalar(@jobs), 0, 'webhook jobs were processed';

    my $args = shift @{ $LWP::UserAgent::POST_ARGS{ $hook_url } };
    my $json = $args->{payload};
    ok $json, 'has json payload';
    my $hook_arg = decode_json($json);
    is_deeply $hook_arg, $event, 'hook arg matches match';
}
