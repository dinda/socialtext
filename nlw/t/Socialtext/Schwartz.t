#!/usr/bin/perl
use strict;
use warnings;
use Test::Socialtext qw/no_plan/;

fixtures 'rdbms_clean';

BEGIN {
    use_ok 'Socialtext::Schwartz', qw/work_asynchronously list_jobs clear_jobs/;
}

Queue_job: {
    clear_jobs();
    my @jobs = list_jobs( 
        funcname => 'Test',
    );
    is scalar(@jobs), 0, 'no jobs to start with';

    work_asynchronously( 'Test', test => 1 );

    @jobs = list_jobs( 
        funcname => 'Test',
    );
    is scalar(@jobs), 1, 'found a job';
    my $j = shift @jobs;
    is $j->funcname, 'Socialtext::Job::Test', 'funcname is correct';

    clear_jobs();
    is scalar(@jobs), 0, 'cleared the jobs';
}
