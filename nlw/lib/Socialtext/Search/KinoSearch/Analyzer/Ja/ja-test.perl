#!/usr/bin/perl

use lib '../../../../..';
use Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif;

# This is not "use bytes"!!!
require bytes;
use Encode qw(encode_utf8);

binmode STDERR, ':utf8';

my $if = Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif->new();
$if->{debug} = 1;

open I, "<ja-test.data";
binmode I, ':utf8';

my @result = $if->analyze(<I>);
close I;
print "@result\n";
