# @COPYRIGHT@
package Socialtext::SearchPlugin;
use strict;
use warnings;

use base 'Socialtext::Query::Plugin';

use Class::Field qw( const field );
use Socialtext::Search qw( search_on_behalf );
use Socialtext::Search::AbstractFactory;
use Socialtext::Pages;
use Socialtext::Workspace;
use Socialtext::l10n qw(loc);
use Socialtext::Log qw( st_log );
use Socialtext::Timer;

sub class_id { 'search' }
const class_title => 'Search';
const cgi_class => 'Socialtext::Search::CGI';

const sortdir => {
    Relevance      => 'desc',
    Summary        => 'asc',
    Subject        => 'asc',
    From           => 'asc',
    Workspace      => 'asc',
    Date           => 'desc',
    revision_count => 'desc',
};

field 'category_search';
field 'title_search';

=head1 DESCRIPTION

This module acts as an adaptor between the Socialtext::Query::Plugin and associated
template interfaces and the Socialtext::Search index/search abstractions.

This keeps our old search-type URLs and templates working with any search
index that implements the interfaces in the Socialtext::Search namespace.

=cut

sub register {
    my $self = shift;
    $self->SUPER::register(@_);
    my $registry = shift;
    $registry->add( wafl => search => 'Socialtext::Search::Wafl' );
    $registry->add( wafl => search_full => 'Socialtext::Search::Wafl' );
}

sub search {
    my $self = shift;
    my $timer = Socialtext::Timer->new;
    # since we dispatch to the heavyweight search in the presence of
    # 'search_term', and since we want to keep track of the original search
    # term when we use the cached results set, we keep a parallel
    # 'orig_search_term' around to populate those links.
    #
    # REVIEW: Icky, gross, patches welcome.
    #
    my $search_term;
    my $workspace_in_search_term;
    my %sortdir = %{$self->sortdir};

    $self->sortby( $self->cgi->sortby || 'Relevance' );

    if ( $self->cgi->defined('search_term') ) {
        $search_term = $self->cgi->search_term;
        if ( $search_term =~ m/workspace\:/ ) {
            $workspace_in_search_term = 1;
        }
        $self->hub->log->debug( 'performing search for '
                . $search_term );
        $self->search_for_term(
            search_term => $search_term,
            scope       => $self->cgi->scope
        );
    }
    $self->result_set( $self->sorted_result_set( \%sortdir ) );

    my $uri_escaped_search_term
        = $self->uri_escape( $search_term );

    st_log()
        ->info( "SEARCH,WORKSPACE,term:'"
            . $search_term
            . "',num_results:"
            . $self->result_set->{hits}
            . ',[' . $timer->elapsed . ']');

    $self->display_results(
        \%sortdir,
        sortby => $self->sortby || 'Relevance',
        allow_relevance => 1,
        search_term => $self->cgi->search_term
            || $self->cgi->orig_search_term,
        scope => $self->cgi->scope || '',
        show_workspace =>
            (          ( $self->cgi->scope ne '_' )
                    || ( $self->cgi->search_term      =~ /\bworkspaces:\S+/ )
                    || ( $self->cgi->orig_search_term =~ /\bworkspaces:\S+/ )
                    || 0 ),
        feeds => $self->_feeds(
            $self->hub->current_workspace, search_term => $search_term,
            scope => $self->cgi->scope,
        ),
        title      => loc('Search Results'),
        unplug_uri => "?action=unplug;search_term="
            . $uri_escaped_search_term,
        unplug_phrase =>
            loc('Click this button to save the pages from this search to your computer for offline use'),
    );
    
}

sub _feeds {
    my $self      = shift;
    my $workspace = shift;
    my %query     = @_;

    my $uri_escaped_query  = $self->uri_escape($query{search_term});
    my $scope = $query{scope};

    my $root  = $self->hub->syndicate->feed_uri_root($workspace);
    # REVIEW: Even though these are not page feeds, they are called
    # page because the template share/template/view/listview looks
    # for rss.page.url to display a feed on the page.
    my %feeds = (
        rss => {
            page => {
                title => loc('[_1] - RSS Search for [_2]', $workspace->title, $query{search_term})
,
                url => $root . "?search_term=$uri_escaped_query;scope=$scope",
            },
        },
        atom => {
            page => {
                title => loc('[_1] - Atom Search for [_2]', $workspace->title, $query{search_term}),
                url => $root . "?search_term=$uri_escaped_query;scope=$scope;type=Atom",
            },
        },
    );

    return \%feeds;
}

sub search_for_term {
    my ( $self, %query )  = @_;
    my $search_term = $query{search_term};
    $self->hub->log->debug("searchquery '" . $search_term . "'");

    $self->result_set( $self->new_result_set );
    eval {
        @{ $self->result_set->{rows} } = $self->_new_search(%query);
        $self->title_search( $search_term =~ s/^=// );
        $self->hub->log->debug("hitcount " . scalar @{ $self->result_set->{rows} });
        foreach my $row ( @{ $self->result_set->{rows} } ) {
            $self->hub->log->debug("hitrow $row->{page_uri}")
                if exists $row->{page_uri};
            $self->hub->log->debug("hitkeys @{ [keys %$row ] }");
        }
        $self->result_set->{hits}          = scalar @{ $self->result_set->{rows} };
        if( $self->title_search ) {
            $self->result_set->{display_title} = loc("Titles containing \'[_1]\' ([_2])", $search_term, $self->result_set->{hits})
        } else {
            $self->result_set->{display_title} = loc("Pages containing \'[_1]\' ([_2])", $search_term, $self->result_set->{hits})
        }
        $self->result_set->{predicate} = 'action=search';
        $self->write_result_set;
    };
    if ($@) {
        if ($@ =~ /malformed query/) {
            $self->error_message($self->template_process(
                    'search_help_field.html',
                )
            );
        } elsif ($@->isa('Socialtext::Exception::NoSuchWorkspace')) {
            $self->error_message(
                  "You tried to search on the workspace named '"
                . $@->name
                . "', which does not exist." );
        } elsif ($@->isa('Socialtext::Exception::Auth')) {
            # FIXME: It would be better to show the name of the workspace
            # they're not authorized to see. -mml 20070504
            $self->error_message(
                  "You are not authorized to perform the requested search." );
        } else {
            $self->hub->log->warning("searchdie '$@'");
        }
    }
}

sub _new_search {
    my ( $self, %query ) = @_;

    my @hits = search_on_behalf(
        $self->hub->current_workspace->name,
        $query{search_term},
        $query{scope},
        $self->hub->current_user,
        sub { },    # FIXME: We'd rather message the user than ignore these.
        sub { }     # FIXME: We'd rather message the user than ignore these.
    );

    my %cache;
    my @results;

    for my $hit (@hits) {
        my $key = $hit->composed_key;
        next if $cache{$key};
        my $row;
        eval {
            $row = $self->_make_row($hit);
        };
        next if $@; # REVIEW: this seems weird, it wasn't necessary before
        # Only add non-empty rows to the result_set.
        if (defined $row and keys %$row) {
            $cache{$key}++;
            push @results, $row;
        }
    }

    return @results;
}

sub _hub_for_workspace {
    my ( $self, $workspace ) = @_;

    my $hub = $self->hub;
    if ( $workspace->name ne $self->hub->current_workspace->name ) {
        my $main = Socialtext->new();
        $main->load_hub(
            current_user      => $self->hub->current_user,
            current_workspace => $workspace
        );
        $main->hub->registry->load;

        $hub = $main->hub;
    }

    return $hub;
}

sub _make_row {
    my ( $self, $hit ) = @_;

    # Establish the proper hub for the hit
    my $workspace = $self->hub->current_workspace();
    eval {
        $workspace
            = Socialtext::Workspace->new( name => $hit->workspace_name );
    };
    my $hit_hub = $self->_hub_for_workspace( $workspace );

    my $page;
    my $attachment;
    my $is_page_deleted;
    my $metadata;
    my $author;
    my $resource_link;
    
    my $page_uri = $hit->page_uri;
    $page = $hit_hub->pages->new_page($page_uri);
    $is_page_deleted = $page->deleted;

    if ( not $is_page_deleted ) {
        $metadata      = $page->metadata;
        $author        = $page->last_edited_by;
    }

    return {} if $is_page_deleted;

    # $author will be undef if the page_uri in the index
    # does not correspond with any existing page. This can happen
    # when pages with page ids are created (happened in the
    # way past, but is cleared up now).
    unless ($author) {
        $self->hub->log->warning( 'search result skipped: '
                . $workspace->name . ': \''
                . $page_uri
                . '\' has no author or is a bad page id' );
        return {};
    }

    my $author_name = $author->best_full_name(
        workspace => $workspace );

    my $document_title = $metadata->Subject;
    my $date = $metadata->Date;
    my $date_local = $page->datetime_for_user;
    my $snippet = $hit->snippet || $page->preview_text;
    my $id = $page->id;

    if ( $hit->isa('Socialtext::Search::AttachmentHit') ) {
        my $attachment_id = $hit->attachment_id;
        $attachment = $hit_hub->attachments->new_attachment(
            id      => $attachment_id,
            page_id => $page_uri,
        )->load();

        return {} if $attachment->deleted;
        $snippet = $hit->snippet || $attachment->preview_text;
        $document_title = $attachment->{filename};
        $date = $attachment->{Date};
        $date_local = $self->hub->timezone->date_local( $date );
        $id = $attachment->id;
        $author = $attachment->uploaded_by;
    }

    return +{
        Relevance           => $hit->hit->{score},
        Date                => $date,
        Revision            => $metadata->Revision,
        Summary             => $snippet,
        document_title      => $document_title,
        Subject             => $metadata->Subject,
        DateLocal           => $date_local,
        revision_count      => $page->revision_count,
        page_uri            => $page->uri,
        page_id             => $page->id,
        id                  => $id,
        username            => $author->username,
        Workspace           => $workspace->title,
        workspace_name      => $workspace->name,
        workspace_title     => $workspace->title,
        is_attachment       => $hit->isa('Socialtext::Search::AttachmentHit'),
    };
}

sub get_result_set {
    my ( $self, %query ) = @_;
    my %sortdir = %{$self->sortdir};
    $self->search_for_term(%query);
    return $self->sorted_result_set(\%sortdir);
}

sub write_result_set {
    my $self = shift;
    eval { $self->SUPER::write_result_set(@_); };
    if ($@) {
        unless ( $@ =~ /lock_store.al/ ) {
            die $@;
        }
        undef($@);
    }
}

package Socialtext::Search::CGI;

use base 'Socialtext::Query::CGI';
use Socialtext::CGI qw( cgi );

cgi search_term => '-html_clean';
cgi orig_search_term => '-html_clean';

######################################################################
package Socialtext::Search::Wafl;

use base 'Socialtext::Query::Wafl';
use Socialtext::l10n qw(loc);

sub _set_titles {
    my $self = shift;
    my $arguments = shift;
    my $title_info;
    if ( $self->target_workspace ne $self->current_workspace_name ) {
        $title_info = loc('Search for [_1] in workspace [_2]', $arguments, $self->target_workspace);
    } else {
        $title_info = loc('Search for [_1]', $arguments);
    }
    $self->wafl_query_title($title_info);
    $self->wafl_query_link($self->_set_query_link($arguments));
}

sub _set_query_link {
    my $self = shift;
    my $arguments = shift;
    return $self->hub->viewer->link_dictionary->format_link(
        link => 'search_query',
        workspace => $self->target_workspace,
        search_term => $self->uri_escape($arguments),
    );
}

sub _get_wafl_data {
    my $self = shift;
    my $hub            = shift;
    my $query          = shift;
    my $workspace_name = shift;
    my $main;

    $hub = $self->hub_for_workspace_name( $workspace_name );

    # This is important so that we only see results that the current user is
    # authorized to see (and we see all such results).
    $hub->current_user($self->hub->current_user);

    $hub->search->get_result_set( search_term => $query );
}

sub _format_results {
    my ( $self, $results, $separator, $wafl ) = @_;

    my $rows = $results->{rows};

    my $wikitext = $separator . join( $separator,
        map {
            "{$wafl "
                . (
                  $self->hub->current_workspace->name ne $_->{workspace_name}
                ? $_->{workspace_name}
                : '' )
                . " ["
                . $_->{Subject} . ']}'
            } @$rows
    );

    return $self->hub->viewer->text_to_html($wikitext. "\n\n");
}

1;
