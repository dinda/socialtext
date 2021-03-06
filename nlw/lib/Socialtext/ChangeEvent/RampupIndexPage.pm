# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::ChangeEvent::RampupIndexPage - specialization of 
L<Socialtext::ChangeEvent::Page> for updating rampup indexes.

=head1 SEE

See L<Socialtext::ChangeEvent::Page>.

=cut

package Socialtext::ChangeEvent::RampupIndexPage;

use base 'Socialtext::ChangeEvent::Page';

use Carp 'croak';
use Readonly;

Readonly my $LINK_BASENAME => 'RampupIndexPage-';

sub new {
    my ( $class, $path, $link_path ) = @_;

    ( $link_path =~ qr{$LINK_BASENAME} ) or return '';

    $class->SUPER::new($path, $link_path);
}

sub _link_to { shift->SUPER::_link_to(@_, $LINK_BASENAME); }

1;
