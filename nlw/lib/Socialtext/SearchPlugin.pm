# @COPYRIGHT@
package Socialtext::SearchPlugin;
use strict;
use warnings;

use base 'Socialtext::Query::Plugin';

use Class::Field qw( const field );
use Socialtext::Search qw( search_on_behalf );
use Socialtext::Search::AbstractFactory;
use Socialtext::Model::Pages;
use Socialtext::Workspace;
use Socialtext::l10n qw(loc);
use Socialtext::Log qw( st_log );
use Socialtext::Timer;
use Socialtext::Pageset;

sub class_id { 'search' }
const class_title => 'Search';
const cgi_class => 'Socialtext::Search::CGI';

const sortdir => {
    Relevance      => 'desc',
    Summary        => 'asc',
    Subject        => 'asc',
    Workspace      => 'asc',
    Date           => 'desc',
    revision_count => 'desc',
    username       => 'asc',
};

field 'category_search';
field 'title_search';

# Per object (request) cache mapping a workspace name to a 
# Workspace object;
field '_workspace_cache' => {};

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

    $self->sortby( $self->cgi->sortby || 'Relevance' );

    my $search_term;
    my $scope = $self->cgi->scope || '_';

    if ($self->cgi->defined('search_term')) {
        $search_term = $self->cgi->search_term;
        $self->dont_use_cached_result_set();
    }
    elsif ($self->cgi->defined('orig_search_term')) {
        $search_term = $self->cgi->orig_search_term;
    }
    else {
        die "no search term?!";
    }

    $self->hub->log->debug("performing search for $search_term");

    # load the search result which may or may not be cached. 
    $self->result_set(
        $self->get_result_set(
            search_term => $search_term,
            scope       => $scope,
        )
    );

    my $uri_escaped_search_term = $self->uri_escape($search_term);

    st_log()
        ->info( "SEARCH,WORKSPACE,term:'$search_term',"
            . "num_results:" . $self->result_set->{hits}
            . ',[' . $timer->elapsed . ']');

    use constant PAGE_SIZE => 10;
    use constant MAX_PAGE_SIZE => 100;
    my ($offset) = ($self->cgi->offset =~ /^(\d+)$/);
    $offset ||= 0;
    my ($limit) = ($self->cgi->limit =~ /^(\d+)$/);
    $limit ||= PAGE_SIZE;
    if ($limit > MAX_PAGE_SIZE) {
        $limit = MAX_PAGE_SIZE;
    }

    $self->display_results(
        $self->sortdir,
        sortby => $self->sortby,
        allow_relevance => 1,
        search_term => $search_term,
        scope => $scope,
        show_workspace =>
            ( ($scope ne '_') || ($search_term =~ /\bworkspaces:\S+/) || 0 ),
        feeds => $self->_feeds(
            $self->hub->current_workspace, 
            search_term => $search_term,
            scope => $scope,
        ),
        title => loc('Search Results'),
        unplug_uri => "?action=unplug;search_term=$uri_escaped_search_term",
        unplug_phrase =>
            loc('Click this button to save the pages from this search to your computer for offline use'),
        Socialtext::Pageset->new(
            cgi => {$self->cgi->all},
            total_entries => $self->result_set->{hits},
        )->template_vars(),
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
    my $scope = $query{scope} || '_';
    $self->{_current_search_term} = $search_term;
    $self->{_current_scope} = $scope;
    $self->hub->log->debug("searchquery '" . $search_term . "'");

    Socialtext::Timer->Continue('search_for_term');
    $self->result_set($self->new_result_set);
    my $result_set = $self->result_set;
    eval {
        my @rows = $self->_new_search(%query);
        $self->title_search($search_term =~ s/^=//);
        $self->hub->log->debug("hitcount " . scalar @rows);
        foreach my $row (@rows) {
            $self->hub->log->debug("hitrow $row->{page_uri}")
                if exists $row->{page_uri};
            $self->hub->log->debug("hitkeys @{[keys %$row]}");
        }

        $result_set->{hits} = scalar @rows;
        $result_set->{rows} = \@rows;

        if( $self->title_search ) {
            $result_set->{display_title} = 
                loc("Titles containing \'[_1]\'", $search_term);
        } else {
            $result_set->{display_title} = 
                loc("Pages containing \'[_1]\'", $search_term);
        }
        $result_set->{predicate} = 'action=search';

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
    Socialtext::Timer->Pause('search_for_term');
}

sub _new_search {
    my ( $self, %query ) = @_;

    Socialtext::Timer->Continue('search_on_behalf');
    $self->{_current_search_term} = $query{search_term};
    $self->{_current_scope} = $query{scope} || '_';
    my @hits = search_on_behalf(
        $self->hub->current_workspace->name,
        $query{search_term},
        $query{scope},
        $self->hub->current_user,
        sub { },    # FIXME: We'd rather message the user than ignore these.
        sub { }     # FIXME: We'd rather message the user than ignore these.
    );
    Socialtext::Timer->Pause('search_on_behalf');

    eval { $self->_load_pages_for_hits(\@hits) };
    warn $@ if $@;

    my %cache;
    my @results;
    Socialtext::Timer->Continue('hitrows');
    for my $hit (@hits) {
        my $key = $hit->composed_key;
        next if $cache{$key};
        my $row = $self->_make_row($hit);

        # Only add non-empty rows to the result_set.
        if (defined $row and keys %$row) {
            $cache{$key}++;
            push @results, $row;
        }
    }
    Socialtext::Timer->Pause('hitrows');

    return @results;
}

# Fetch pages in the bulk per workspace for search results
# We'll stick the pageref in the hit object for later
sub _load_pages_for_hits {
    my $self = shift;
    my $hits = shift;
    
    my %pages;
    for my $hit (@$hits) {
        push @{$pages{$hit->workspace_name}{$hit->page_uri}}, $hit;
    }
    for my $workspace_name (keys %pages) {
        my ($workspace, $hit_hub)
            = $self->_load_hit_workspace_and_hub($workspace_name);
        my $wksp_pages = $pages{$workspace_name};
        my $pages = [];
        eval {
            $pages = Socialtext::Model::Pages->By_id(
                hub              => $hit_hub,
                workspace_id     => $workspace->workspace_id,
                page_id          => [ keys %$wksp_pages ],
                do_not_need_tags => 1,
            );
        };
        warn $@ if $@;
        $pages = [$pages] unless (ref($pages) || '') eq 'ARRAY';

        for my $page (@$pages) {
            my $page_hits = $wksp_pages->{$page->id};
            for my $hit (@$page_hits) {
                $hit->{page} = $page;
            }
        }
    }
}

sub _load_hit_workspace_and_hub {
    my $self = shift;
    my $workspace_name  = shift;

    if (my $hit = $self->_workspace_cache->{$workspace_name}) {
        return ($hit->{workspace}, $hit->{hub});
    }

    # Establish the proper hub for the hit
    my $hub = $self->hub;
    my $workspace;
    eval { $workspace = Socialtext::Workspace->new(name => $workspace_name) };
    if ( $workspace->name ne $hub->current_workspace->name ) {
        my $main = Socialtext->new();
        $main->load_hub(
            current_user      => $hub->current_user,
            current_workspace => $workspace
        );
        $main->hub->registry->load;
        $hub = $main->hub;
    }

    # Seed the cache for next time
    $self->_workspace_cache->{$workspace_name} = {
        workspace => $workspace,
        hub       => $hub,
    };
    return ($workspace, $hub);
}

sub _make_row {
    my ( $self, $hit ) = @_;

    my ($workspace, $hit_hub)
        = $self->_load_hit_workspace_and_hub($hit->workspace_name);

    my $page_uri = $hit->page_uri;
    my $page;
    eval {
        $page = $hit->{page} || Socialtext::Model::Pages->By_id(
            hub          => $hit_hub,
            workspace_id => $workspace->workspace_id,
            page_id      => $page_uri,
        );
    };
    return {} if !$page or $page->deleted;

    my $author = $page->last_edited_by;
    my $document_title = $page->title;
    my $date = $page->last_edit_time;
    my $date_local = $page->datetime_for_user;
    my $snippet = $hit->snippet || $page->summary;
    my $id = $page->id;
    my $attachment;
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
        Revision            => $page->current_revision_num,
        Summary             => $snippet,
        document_title      => $document_title,
        Subject             => $page->title,
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
        is_spreadsheet      => $page->is_spreadsheet,
    };
}

sub get_result_set {
    my ( $self, %query ) = @_;
    my %sortdir = %{$self->sortdir};
    $self->{_current_search_term} = $query{search_term};
    $self->{_current_scope} = $query{scope};
    if (!$self->{_current_search_term}) {
        $self->result_set($self->new_result_set());
    }
    else {
        $self->result_set($self->read_result_set());
    }
    return $self->sorted_result_set(\%sortdir);
}

sub default_result_set {
    my $self = shift;
    die "default_result_set called without a _current_search_term"
        unless $self->{_current_search_term};
    $self->search_for_term(
        search_term => $self->{_current_search_term},
        scope => $self->{_current_scope},
    );
    return $self->result_set;
}

sub read_result_set {
    my $self = shift;

    # try to get the cached result
    my $result_set = $self->SUPER::read_result_set(@_);

    # if we get one, make sure it's for the right search
    if ($result_set && 
        defined($result_set->{search_term}) && 
        $result_set->{search_term} eq $self->{_current_search_term} &&
        defined($result_set->{scope}) &&
        $result_set->{scope} eq $self->{_current_scope})
    {
        return $result_set;
    }
    else {
        # should do a new search
        return $self->default_result_set;
    }
}

sub write_result_set {
    my $self = shift;
    $self->result_set->{search_term} = $self->{_current_search_term};
    $self->result_set->{scope} = $self->{_current_scope};
    eval { $self->SUPER::write_result_set(@_); };
    if ($@) {
        unless ( $@ =~ /lock_store.al/ ) {
            die $@;
        }
        undef($@);
    }
}

sub show_summaries {
    my $self = shift;

    return ( defined $self->cgi->summaries and $self->cgi->summaries ne '' )
        ? $self->cgi->summaries
        : 1;
}

package Socialtext::Search::CGI;

use base 'Socialtext::Query::CGI';
use Socialtext::CGI qw( cgi );

cgi search_term => '-html_clean';
cgi orig_search_term => '-html_clean';
cgi 'offset';
cgi 'limit';

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
