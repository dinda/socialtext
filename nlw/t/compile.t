#!perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::More;

my @modules = all_modules();

plan tests => scalar @modules;

sub main {
    for (@modules) {
        SKIP: {
            skip "$_ Doesn't compile.", 1 if module_doesnt_compile();
            use_ok($_);
        }
    }
}

sub all_modules {
    open my $find, 'find lib -name \*.pm |' or die "find: $!";

    map { path2module() } <$find>;
}

# Translate a pathname to a module name.
sub path2module {
    chomp;
    s{^lib/|\.pm$}{}g;
    s{/}{::}g; $_
}

{
    my $bad_module_pat
        = '^' . ( join '|', map { chomp; quotemeta $_ } <DATA> ) . '$';

    # Return true if the module in `$_` is in our skip list.
    sub module_doesnt_compile { /$bad_module_pat/ }
}

main();

# List below modules that don't compile.
__DATA__
Socialtext::Handler::Cleanup
Socialtext::MasonHandler
Socialtext::SOAPServer
Socialtext::User::LDAP
Socialtext::WebApp::Authen
Socialtext::Challenger::OpenId
Socialtext::Handler::REST
Socialtext::Rest::Hydra
Socialtext::WikiFixture::Socialtext
Test::SeleniumRC
