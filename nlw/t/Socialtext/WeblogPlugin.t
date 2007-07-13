#!perl
# @COPYRIGHT@

use strict;
use warnings;
use utf8;

use Test::Socialtext tests => 12;
fixtures( 'admin_no_pages' );

BEGIN {
    use_ok( 'Socialtext::WeblogPlugin' );
}

WEBLOG_CACHE: {
    my $hub = new_hub('admin');

    $hub->weblog->current_weblog('socialtext blog');
    $hub->weblog->update_current_weblog();
    is $hub->weblog->current_blog, 'socialtext blog',
        'cache is written with socialtext blog';
}

WEBLOG_TITLE_IS_VALID: {
    my $hub = new_hub('admin');
   
    #
    # Check length boundary conditions.
    #
    ok( ! $hub->weblog->_weblog_title_is_valid('a'),
       'Too-short weblog name fails'
    );
    ok( ! $hub->weblog->_weblog_title_is_valid('a' x 29),
       'Too-long weblog name fails'
    );
    ok( $hub->weblog->_weblog_title_is_valid('aa'),
        'Weblog name of exactly 2 characters succeeds'
    );
    ok( $hub->weblog->_weblog_title_is_valid('a' x 28),
        'Weblog name of exactly 28 characters succeeds'
    );

    #
    # Check the name which had utf8 characters.
    #
    ok( ! $hub->weblog->_weblog_title_is_valid('あ'),
       'Too-short weblog name which had utf8 fails'
    );
    ok( ! $hub->weblog->_weblog_title_is_valid('あ' x 29),
       'Too-long weblog name which had utf8 fails'
    );
    ok( $hub->weblog->_weblog_title_is_valid('ああ'),
        'Weblog name of exactly 2 utf8 characters succeeds'
    );
    ok( $hub->weblog->_weblog_title_is_valid('あ' x 28),
        'Weblog name of exactly 28 utf8 characters succeeds'
    );
}

WEBLOG_NAME_TO_ID: {
    my $hub = new_hub('admin');

    #
    # Check creating the page object.
    #
    eval {
        $hub->weblog->_create_first_post('a' x 28);
    };

    ok( !$@, 'Createing Weblog page object succeeds');

    #
    # Check creating the page object which had utf8 characters.
    #
    eval {
        $hub->weblog->_create_first_post('あ' x 28 . '最初の投稿');
    };

    ok( !$@, 'Createing Weblog page object which had utf8 characters succeeds');


}

