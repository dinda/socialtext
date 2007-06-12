#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 4;

use_ok('Socialtext::EmailReceiver::Factory');

my $hub = new_hub('admin');
isa_ok( $hub, 'Socialtext::Hub' );
my $ws = $hub->current_workspace();

CREATE_EN: {

    my $locale = 'en';
    my $string = 'hogehoge';
    ok ( eval{
            my $receiver = Socialtext::EmailReceiver::Factory->create(
                {
                    locale => $locale,
                    string => $string,
                    workspace => $ws,
                });
        });
}

CREATE_JA: {

    my $locale = 'ja';
    my $string = 'hogehoge';
    ok ( eval{
            my $receiver = Socialtext::EmailReceiver::Factory->create(
                {
                    locale => $locale,
                    string => $string,
                    workspace => $ws,
                });
        });
}

