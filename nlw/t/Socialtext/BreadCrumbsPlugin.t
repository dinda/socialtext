#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 35;
use mocked 'Apache::Cookie';
use mocked 'Apache::Cookie';
fixtures( 'admin_no_pages', 'foobar_no_pages' );

BEGIN {
    use_ok( "Socialtext::BreadCrumbsPlugin" );
}

my $admin  = new_hub('admin');
my $foobar = new_hub('foobar');

my @pages;
for ( 1..3 ) {
    my $page = $admin->pages->new_from_name( "Page $_" );
    $page->content("Hello\nthis is page$_\n");
    $page->metadata->Subject("page$_");
    $page->metadata->update( user => $admin->current_user);
    $page->store( user => $admin->current_user );
    push @pages, $page;

    my $fpage = $foobar->pages->new_from_name( "Foobar Page $_" );
    $fpage->content("Hello\nthis is page$_\n");
    $fpage->metadata->Subject("page$_");
    $fpage->metadata->update( user => $foobar->current_user );
    $fpage->store( user => $foobar->current_user );
}

is scalar @{$admin->breadcrumbs->get_crumbs}, 0, 'no crumbs dropped yet';

display_and_check_crumbs( $admin,  'Page 1', ['page_1'] );
display_and_check_crumbs( $foobar, 'Foobar Page 1', [qw'foobar_page_1'] );
display_and_check_crumbs( $admin,  'Page 2',       [qw'page_2 page_1'] );
display_and_check_crumbs( $foobar, 'Foobar Page 2',
    [qw'foobar_page_2 foobar_page_1'] );
display_and_check_crumbs( $admin, 'Page 3', [qw'page_3 page_2 page_1'] );
display_and_check_crumbs( $foobar, 'Foobar Page 3',
    [qw'foobar_page_3 foobar_page_2 foobar_page_1'] );
display_and_check_crumbs( $admin, 'Page 2', [qw'page_2 page_3 page_1'] );
display_and_check_crumbs( $foobar, 'Foobar Page 2',
    [qw'foobar_page_2 foobar_page_3 foobar_page_1'] );

# TODO - add TODO test that when you delete a page it is removed from
# the breadcrumbs

$admin->pages->new_from_name('page 2')->delete( user => $admin->current_user );
display_and_check_crumbs( $admin, 'Page 3', [qw'page_3 page_1'] );

wipe_out_trail_file($admin->breadcrumbs);
is_deeply(
    $admin->breadcrumbs->default_result_set(),
    $admin->breadcrumbs->new_result_set(),
    'When no .trail file is around, the default result set is the same as the new result set.'
);

# recreate the .trail file
display_and_check_crumbs( $admin,  'Page 1', ['page_1'] );

# calculate the result set
my $plain_result_set = $admin->breadcrumbs->result_set;

# make sure we can sort it
# my %sortdir_hash = (sortby => 'revision_count', direction => 1);
# my $sorted_result_set = $admin->breadcrumbs->sorted_result_set(\%sortdir_hash);

# wipe out the on-disk cache
wipe_out_cache($admin->breadcrumbs);

# check that it gets recreated properly in standard and sorted varieties
is_deeply(
    $admin->breadcrumbs->result_set,
    $plain_result_set,
    'Recreated result set is the same as that prior to cache file getting clobbered.'
);
# is_deeply(
# $admin->breadcrumbs->sorted_result_set(\%sortdir_hash),
# $sorted_result_set,
# 'Recreated sorted result set is the same as that prior to cache file getting clobbered.'
# );

sub display_and_check_crumbs {
    my $hub    = shift;
    my $title  = shift;
    my $expect = shift;

    $hub->pages->current($hub->pages->new_from_name($title));
    $hub->display->display;

    my $crumbs = $hub->breadcrumbs->get_crumbs;
    my $num = scalar @$expect;
    is scalar @$crumbs, $num, "$num crumbs dropped";

    for my $t (@$expect) {
        is( (shift @$crumbs)->{page_uri}, $t, "page uri in crumbs == '$t'" );
    }
}

sub wipe_out_trail_file {
    my $breadcrumbs = shift;
    unlink $breadcrumbs->_trail_filename;
}

sub wipe_out_cache {
    my $breadcrumbs = shift;
    unlink $breadcrumbs->get_result_set_path;
}
