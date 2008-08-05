package Socialtext::Cache;

use strict;
use warnings;
use Cache::MemoryCache;

# if we ever forget to clear, make sure that caches auto-purge periodically.
our $DefaultExpiresIn = '1m';

# cache class used
our $CacheClass = 'Cache::MemoryCache';

sub cache {
    my ($class, $name) = @_;
    return $CacheClass->new( {
        namespace           => $name,
        default_expires_in  => $DefaultExpiresIn,
        auto_purge_on_get   => 1,
        } );
}

sub clear {
    my ($class, $name) = @_;
    if ($name) {
        my $cache = $class->cache($name);
        $cache->clear()
    }
    else {
        $CacheClass->Clear();
    }
}

sub names {
    my $class = shift;
    return $class->cache('only-so-we-can-instantiate-a-cache-object')->get_namespaces();
}

1;

=head1 NAME

Socialtext::Cache - In-memory named caches

=head1 SYNOPSIS

  # get a named cache, and interact with it
  $cache = Socialtext::Cache->cache('user_id');

  $user_id_rec = $cache->get($user_id);
  $cache->set($user_id, $user_id_rec);

  # clear/flush a cache by its handle
  $cache->clear();

  # clear/flush a cache by its name
  Socialtext::Cache->clear('user_id');

  # clear/flush *all* named caches
  Socialtext::Cache->clear();

  # get the list of named caches 
  @names = Socialtext::Cache->names();

=head1 DESCRIPTION

C<Socialtext::Cache> implements a single point of entry for a series of named
in-memory caches (using C<Cache::MemoryCache>).

Need a cache somewhere?  Just create a new one and start using it.

Worried about dangling caches?  Don't; C<Socialtext::Cache->clear()> will be
called at the end of the HTTP request, and all of the caches will be flushed
automatically.

Your only concern should be using the cache to help speed things up where
caching will be effective.

Further, B<don't> be concerned with trying to keep the cache up-to-date when
things change, B<just clear the whole cache and be done with it>.  Brutal?
Yes.  Easier than trying to keep the cache coherent in the face of any
possible change?  Yes.

Is a plain old hash faster?  Probably.  Is a hash better?  Maybe.  If you use
C<Socialtext::Cache>, though, and we later find that switching to a shared
memory cache or a file cache provides better re-use or increases the hit
ratio, you'll get all that benefit for free.

=head1 METHODS

=over

=item B<Socialtext::Cache-E<gt>cache($name)>

Retrieves the given named cache object.  Its created automatically if it
doesn't already exist.

=item B<Socialtext::Cache-E<gt>clear($name)>

Clears the given named cache, removing B<all> entries from the cache.

If no C<$name> is provided, this method clears B<ALL> of the caches.

=item B<Socialtext::Cache-E<gt>names()>

Returns a list of the named caches that have data in them.  If a cache was
created but then never had any data placed into it, it won't appear in this
list.

This method is provided solely for debugging purposes.  You shouldn't need to
iterate across a list of named caches in any common usage; just create the
named cache you want/need and start using it.

=back

=head1 AUTHOR

Socialtext, Inc.  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Cache::Cache>,
L<Cache::MemoryCache>.

=cut
