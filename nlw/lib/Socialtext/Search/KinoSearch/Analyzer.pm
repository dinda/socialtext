# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Analyzer;
use strict;
use warnings;
use base 'Socialtext::Search::KinoSearch::Analyzer::Base';
use YAML qw(LoadFile);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);

use Data::Dumper;
sub dump_it_for_me {
    my ($msg, $batch) = @_;
    print STDERR "ST:S:KS:A:analyze $msg batch\n";
    print STDERR "BEGIN\n";
    $batch->reset;
    my $ix = 0;

    while ($batch->next) {
	$ix++;
	my $text = $batch->get_text;
	$batch->set_text($text);
	print STDERR "$ix: $text\n";
    }
    $batch->reset;
    print STDERR "END\n";
}

my $CONFIG;

sub analyze {
    my ( $self, $input ) = @_;
    my $batch = $self->_get_batch_from_input($input);

    dump_it_for_me('initial', $batch);
    for my $class ( _get_analyzer_classes( $self->{language} ) ) {
        eval "require $class; 1;";
        die "Could not load $class $@\n" if $@;
        my $analyzer = $class->new( language => $self->{language} );
        $batch = $analyzer->analyze($batch);
	dump_it_for_me("post $class", $batch);
    }
    return $batch;
}

sub _get_analyzer_classes {
    my $lang   = shift;
    my $config = _get_analyzer_config();
    $lang = $config->{DEFAULT} unless exists $config->{$lang};
    return @{ $config->{$lang} };
}

sub _get_analyzer_config {
    return $CONFIG if $CONFIG;
    my $dir  = dirname(__FILE__);
    my $file = catfile( $dir, "analyzer_conf.yaml" );
    $CONFIG = LoadFile($file);
    my $default = $CONFIG->{DEFAULT} || 'en';
    unless ( _get_analyzer_classes($default) ) {
        die "No default analyzers found in $file.  These are required!\n";
    }
    return $CONFIG;
}

1;
