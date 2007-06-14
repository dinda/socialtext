#!perl
# @COPYRIGHT@
use strict;
use warnings;

BEGIN {
    use mocked 'Apache';
    use mocked 'Socialtext::l10n', qw(system_locale);
    use Socialtext::Workspace;

    use Test::Socialtext tests => 5;
    fixtures('help');

    use_ok('Socialtext::Handler::Help');
}

GET_URI: {
    my $r = FakeRequest->new();
    $r->uri("/help/foo/matthew/index.cgi");
    $r->args("like=2;love=97");
    my $uri = Socialtext::Handler::Help::get_uri( $r, "cows" );
    is( $uri, "/cows/foo/matthew/index.cgi?like=2;love=97" );
}

HANDLER_REDIRECT: {
    system_locale('en');
    my $r = FakeRequest->new();
    $r->uri("/help/index.cgi");
    $r->args("socialtext_documentation");
    Socialtext::Handler::Help->real_handler($r);
    is($r->status, 302, "Status is redirect");
    is_deeply( $r->header_out,
        [ Location => "/help-en/index.cgi?socialtext_documentation" ],
        "Location header is good" 
    );
}

HANDLER_REDIRECT: {
    system_locale('xx');
    Socialtext::Workspace->new(name => 'help-en')->delete();
    my $r = FakeRequest->new();
    $r->uri("/help/index.cgi");
    $r->args("socialtext_documentation");
    Socialtext::Handler::Help->real_handler($r);
    is($r->status, 404, "Status is 404 for help-xx");
}

package FakeRequest;

sub new { bless( {}, shift ) }

sub AUTOLOAD {
    our $AUTOLOAD;
    my $self = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.*://;
    return if $method eq 'DESTROY';

    $self->{$method} = shift if @_ == 1;
    $self->{$method} = [@_]  if @_ > 1;
    die "Method undefined: $method\n" unless exists $self->{$method};
    return $self->{$method};
}
