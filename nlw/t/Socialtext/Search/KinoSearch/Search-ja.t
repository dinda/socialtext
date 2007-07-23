#!/usr/bin/env perl
# -*- coding: utf-8 -*- vim:fileencoding=utf-8:
# @COPYRIGHT@
use strict;
use warnings;

use utf8;
use Test::Socialtext tests => 12;
fixtures( 'admin_no_pages' );


BEGIN { 
    unlink "t/tmp/etc/socialtext/socialtext.conf";
}

local *Socialtext::l10n::system_locale = sub {
   return 'ja';
};

use_ok("Socialtext::Search::KinoSearch::Factory");

our $workspace = 'admin';
our $hub = new_hub('admin');

BASIC_SEARCH: {
    erase_index_ok();
    make_page_ok(
        "ひらがな",
        "シリコンバレーの天気はいつも良好です"
    );
    search_ok( "シリコンバレー", 1, "Simple Hiragana search" );
    search_ok( "天気", 1, "Simple Kanji search" );
    search_ok( "ひらがな", 1, "Simple Hiragana word search (in title)" );
}

MORE_FEATURED_SEARCH: {
    erase_index_ok();
    make_page_ok( "Tom Stoppard", <<'QUOTE', [ "漢字", "ひらがな", "カタカナ"] );
シリコンバレーでの天気はいつも良好。
QUOTE
    search_ok(
        "シリコンバレー 天気", 1,
        "Assert searching defaults to AND connectivity"
    );
    search_ok( "tag:ひらがな", 1, "Tag search with word which is standalone" );
    search_ok( "tag:漢字", 1, "Tag search with word not also standalone" );
    search_ok( "tag:カタカナ", 1, "Tag search with word not also standalone" );
}

#----------------------------------------------------------
# Utility methods
#----------------------------------------------------------
sub make_page_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ( $title, $content, $tags ) = @_;
    my $page = $hub->pages->new_from_name($title);
    $page->update(
        user             => $hub->current_user,
        subject          => $title,
        content          => $content,
        categories       => $tags || [],
        original_page_id => $page->id,
        revision         => $page->metadata->Revision || 0,
    );
    index_ok( $page->id );

    return $page;
}

sub search_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ( $term, $num_of_results, $text ) = @_;
    my @results = eval { searcher()->search($term) };
    diag($@) if $@;

    my $hits = ( $num_of_results == 1 ) ? "hit" : "hits";
    is(
        scalar @results,
        $num_of_results,
        "'$term' returns $num_of_results $hits: $text"
    );

    return @results;
}

sub index_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $INDEX_MAX = 60;    # 60 seconds to index a page.

    my $page = shift;
    my $id   = ref($page) ? $page->id : $page;

    # Use a double eval in case the alarm() goes off in between returing from
    # the inner eval and before alarm(0) is executed.
    my $fail;
    eval {
        local $SIG{ALRM} = sub {
            die "Indexing $id is taking more than $INDEX_MAX seconds.\n";
        };
        alarm($INDEX_MAX);
        eval { 
            indexer()->index_page($id);
        };
        $fail = $@;
        alarm(0);
    };

    diag("ERROR Indexing $id: $fail\n") if $fail;
    ok( not($fail), "Indexing $id" );
}

sub erase_index_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    eval { indexer()->delete_workspace($workspace) };
    diag("erase_index_ok: $@\n") if $@;
    ok( not($@), "============ ERASED INDEX =============" );
}

sub searcher {
    Socialtext::Search::KinoSearch::Factory->create_searcher($workspace);
}

sub indexer {
    Socialtext::Search::KinoSearch::Factory->create_indexer($workspace);
}
