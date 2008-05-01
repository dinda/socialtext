#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::HTTP::Socialtext '-syntax', 'no_plan';

use JSON;
use Readonly;
use Test::Live fixtures => ['admin', 'foobar'];
use Test::More;
use Socialtext::Paths;
use YAML;
use URI;

$JSON::UTF8 = 1;

$Test::HTTP::BasicUsername = 'devnull1@socialtext.com';

Readonly my $BASE => Test::HTTP::Socialtext->url('/data/users');
my $rest_path = "$BASE/devnull1%40socialtext.com/preferences/mynamespace/monkey";
my $file_path = Socialtext::Paths::storage_directory(
    join('/', 'userprefs', $Test::HTTP::BasicUsername, 'mynamespace.yaml')
);

if (-f $file_path) {
    unlink $file_path or die "Can't unlink $file_path: $!";
}

test_http "POST new user returns 201" {
    >> POST $rest_path
    >> Content-type: text/plain
    >>
    >> Hello there

    << 201
}

ok(-f $file_path, "File was actually created");
is_deeply(
    YAML::LoadFile($file_path),
    {monkey=>'Hello there'},
    "Content was set properly",
);

test_http "GET returns new content" {
    >> GET $rest_path

    << 200

    my $body = $test->response->decoded_content();
    is $body, "Hello there", "GET returns posted content";
}
