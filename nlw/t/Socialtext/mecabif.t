#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

my ($testcnt, @testcase);
BEGIN {
    my $infile = 't/test-data/ja/mecabif.in';
    open I, '<', $infile;
    binmode I, ':utf8';
    @testcase = <I>;
    $testcnt = 2 + scalar @testcase;
    close I;
}

use Test::Socialtext tests => $testcnt;
use Socialtext::AppConfig;

use_ok 'Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif';
# set_system_locale('ja');
my $if = Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif->new();

isa_ok($if, 'Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif');

for (@testcase) {
    chomp;
    my ($feed, @words) = split(/\t/, $_);
    my %check;
    my $bad = 0;
    for (@words) {
	$check{$_} = 1;
    }
    my $orig = $feed;
    my @result = $if->analyze($feed);
    for (@result) {
	# next if (/^\s+$/);
	if (!exists $check{$_}) {
	    $bad++;
	}
    }
    ok(!$bad, "'$orig' should split to " .
       join(', ', map { "'$_'" } @words));
}
