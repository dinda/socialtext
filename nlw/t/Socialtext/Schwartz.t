#!/usr/bin/perl
use strict;
use warnings;
use Test::Socialtext qw/no_plan/;

fixtures 'rdbms_clean';

BEGIN {
    use_ok 'Socialtext::Schwartz', qw/work_asynchronously list_jobs/;
}

Queue_job: {
    my @jobs = list_jobs( 
        funcname => 'TestJob',
    );
    is scalar(@jobs), 0, 'no jobs to start with';

    work_asynchronously( 'TestJob', test => 1 );

    @jobs = list_jobs( 
        funcname => 'TestJob',
    );
    is scalar(@jobs), 1, 'found a job';
    my $j = shift @jobs;
    is $j->funcname, 'TestJob', 'funcname is correct';
}
