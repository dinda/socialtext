#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin_no_pages' );

format_tt_wafl: {
    my $content = "`++\$bar`\n";
    my $expected = qr|<tt>\+\+\$bar</tt>|;
    formatted_like $content, $expected;
}
