#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More tests => 6;

BEGIN {
    use_ok 'Socialtext::Schema';
}

Sunny_day: {
    my $s = Socialtext::Schema->new;
    isa_ok $s, 'Socialtext::Schema';
}

Update_scripts: {
    local $ENV{ST_SCHEMA_DIR} = 'etc/socialtext/db';
    my $s = Socialtext::Schema->new;
    All: {
        my @scripts = $s->_update_scripts;
        is scalar(@scripts), 5;
    }
    From: {
        my @scripts = $s->_update_scripts( from => 3 );
        is scalar(@scripts), 3;
    }
    To: {
        my @scripts = $s->_update_scripts( to => 3 );
        is scalar(@scripts), 2;
    }
    From_and_to: {
        my @scripts = $s->_update_scripts( from => 2, to => 4 );
        is scalar(@scripts), 2;
    }
}
