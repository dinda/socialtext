# @COPYRIGHT@
package Socialtext::EmailReceiver::ja;

use strict;
use warnings;

use base 'Socialtext::EmailReceiver::Base';
use Socialtext::l10n qw(loc system_locale);

use DateTime::Format::Japanese
    qw(FORMAT_KANJI FORMAT_ERA FORMAT_GREGORIAN FORMAT_ROMAN);

sub format_date {
    my $self     = shift;
    my $datetime = shift;
    my $date_header;

    my $fmt = DateTime::Format::Japanese->new(
        number_format         => FORMAT_ROMAN,
        year_format           => FORMAT_ROMAN,
        with_gregorian_marker => 0,
        with_bc_marker        => 0,
        with_ampm_marker      => 0,
        with_day_of_week      => 1,
        input_encoding        => 'utf8',
        output_encoding       => 'utf8'
    );

    $date_header = $fmt->format_datetime($datetime);
    Encode::_utf8_on($date_header);

    return $date_header;
}

1;

