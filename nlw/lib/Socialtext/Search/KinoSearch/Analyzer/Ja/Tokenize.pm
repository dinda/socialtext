# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Analyzer::Ja::Tokenize;
use strict;
use warnings;
use base 'Socialtext::Search::KinoSearch::Analyzer::Base';

# NOTE. this is not 'use bytes'.
# We only want to be able to call bytes::length(); we do not want
# our strings to be treated as sequence of bytes.
require bytes;
use Encode qw(decode_utf8 encode_utf8);
use KinoSearch::Analysis::TokenBatch;
use Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif;

sub analyze {
    my ($self, $batch) = @_;
    local ($_);
    $batch = $self->_get_batch_from_input($batch);

    my @all;
    while ($batch->next) {
	    push @all, decode_utf8($batch->get_text);
    }

    my $if = Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif->new();

    my $new_batch = KinoSearch::Analysis::TokenBatch->new;
    for ($if->analyze(@all)) {
	    $new_batch->append($_, 0, length($_));
    }
    return $new_batch;
}

1;
