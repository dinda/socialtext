# @COPYRIGHT@
package Socialtext::User::Cache;
use strict;
use warnings;
use Socialtext::Cache;

our $Enabled = 0;
our %stats = (
    fetch => 0,
    store => 0,
);

my %ValidKeys = (
    user_id => 1,
    email_address => 1,
    username => 1,
);

sub Fetch {
    my ($class, $key, $val) = @_;
    return unless $Enabled;
    return unless $ValidKeys{$key};
    $stats{fetch}++;
    my $key_cache = Socialtext::Cache->cache("homunculus:$key");
    return $key_cache->get($val);
}

sub Store {
    my ($class, $key, $val, $user) = @_;
    return unless $Enabled;
    return unless $ValidKeys{$key};
    $stats{store}++;
    my $key_cache = Socialtext::Cache->cache("homunculus:$key");
    return $key_cache->set($val, $user);
}

sub Clear {
    my $cache;
    foreach my $key (keys %ValidKeys) {
        $cache = Socialtext::Cache->cache("homunculus:$key");
        $cache->clear();
    }
}

sub ClearStats {
    map { $stats{$_} = 0 } keys %stats;
}

1;
