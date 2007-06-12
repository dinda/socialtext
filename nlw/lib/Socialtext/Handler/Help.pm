# @COPYRIGHT@
package Socialtext::Handler::Help;
use strict;
use warnings;
use base 'Socialtext::Handler';

use Apache::Constants qw(REDIRECT NOT_FOUND);
use Socialtext::Workspace;

sub real_handler  {
    my ( $class, $r ) = @_;

    # Redirect to the right help workspace, or do a 404.
    my $ws = Socialtext::Workspace->help_workspace();
    if ($ws) {
        my $uri = get_uri( $r, $ws->name );
        $r->header_out( Location => $uri );
        $r->status(302);
        return REDIRECT;
    }
    else {
        $r->status(404);
        return NOT_FOUND;
    }
}

# Redirect the request, but rewrite /help to /$ws where $ws is the real help
# workspace.
sub get_uri {
    my ( $r, $ws_name ) = @_;
    my $path  = $r->uri || "";
    my $query = $r->args ? '?' . $r->args : "";
    my $uri = $path.$query;
    $uri =~ s{/help/}{/$ws_name/};
    return $uri;
}

1;
