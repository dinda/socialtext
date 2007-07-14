package Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif;

use Encode qw(decode_utf8 encode_utf8 encode decode);
use Text::MeCab;

sub new {
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;

	# We reuse a same MeCab instance.  It eats Japanese text
	# stream (use Juman dictionary with it), and tokenizes
	# into runs of words, while annotating what kind of word
	# each of them is and what the "canonical" spelling of
	# the word is.  The latter is of most interest, as we can
	# do away without the stemmer.

	$self->{mecab} = Text::MeCab->new({
		output_format_type => "user",
		node_format => join('\t',
				    ("NODE",	# for easier parsing
				     "%m",	# input word
				     "%f[0]",	# word type
				     "%f[6]",	# auxiliary information
				     )),
	});

	# Many of the words in Japanese are not "interesting" while
	# building indices or performing a search.  Instead of using the
	# word order to differenciate different "cases" (e.g.  nominative,
	# accusative, etc.), Japanese have a class of suffixes that attach
	# to nouns to mark which case the noun is used in the sentence,
	# and they are usually of no interest for text search purposes.
	# This lists the word types that are of interest.
	$self->{handled_types} = +{
		map { $_ => 1 }
		("\306\260\273\354",		# VERB
		 "\314\276\273\354",		# NOUN
		 "\267\301\315\306\273\354",	# ADJECTIVE
		 "\311\373\273\354"		# ADVERB
		 )
	    };

	# The most important part of the auxiliary information
	# is the "canonical" spelling definition, which follows
	# this prefix in the MeCab output.
	$self->{canon_label} = "\302\345\311\275\311\275\265\255:";

	return $self;
}

# MeCab unfortunately does too much.  When given a typical Japanese
# text that has a few English words, URLs and such sprinkled in,
# it removes the punctuation and separates them into words of
# unknown category.  We replace ASCII sequences into stub upfront
# before passing the input to MeCab, and when we read its output back
# replace the stubs into the original, to be processed further with
# Latin rules.
sub replace_ascii {
    my ($token, $ascii_token) = @_;
    my @ret = ();
    while ($token =~ /<<(\d+)>>(.*)/) {
	push @ret, $ascii_token->[$1];
	$token = $2;
    }
    if ($token ne "") {
	push @ret, $token;
    }
    return @ret;
}

sub handle_morph {
	my $self = shift;
	my ($text, $ascii_token) = @_;

	my $mecab = $self->{mecab};
	my $canon_label = $self->{canon_label};
	my $handled_types = $self->{handled_types};

	# MeCab wants its interface in euc-jp.  Don't ask me why.
	$text = encode('euc-jp', $text);

	my $node = $mecab->parse($text);
	my @ret;
	my $in_ascii = '';
	while ($node) {
		my $parsed = $node->format($mecab);
		chomp($parsed);
		my ($n, $word, $type, $aux) = split(/\t/, $parsed);
		$node = $node->next;
		if ($self->{debug} && $parsed ne '') {
			my $d = decode('euc-jp', $parsed);
			print STDERR "MECAB: $d\n";
		}

		next unless (defined $n && $n eq 'NODE');
		if ($word =~ /^[ -~]*$/) {
			# ASCII
			$in_ascii .= $word;
			next;
		}
		next unless (exists $handled_types->{$type});
		if ($aux =~ /$canon_label(\S+)/o) {
			$word = $1;
		}

		if ($in_ascii ne '') {
			push @ret, replace_ascii($in_ascii, $ascii_token);
		}
		$in_ascii = '';
		push @ret, $word;
	}
	if ($in_ascii ne '') {
		push @ret, replace_ascii($in_ascii, $ascii_token);
	}
	if ($self->{debug}) {
		my $ix = 0;
		print STDERR "ANALYSIS\n";
		for (@ret) {
			$ix++;
			my $d = decode('euc-jp', $_);
			print STDERR "$ix: $d\n";
		}
	}
	return map { decode('euc-jp', $_) } @ret;
}

our (%H2Z, $H2Z);
sub add_h2z {
	my ($hash, $decode_eucjp) = @_;

	while (my ($key, $val) = each %$hash) {
		if ($decode_eucjp) {
			$key = decode('euc-jp', $key);
			$val = decode('euc-jp', $val);
		}
		$H2Z{$key} = $val;
		$H2Z .= (defined $H2Z ? '|' : '') . quotemeta($key);
	}
}

sub add_h2z_str {
	my ($from, $to) = @_;
	my $l = length($from);
	if (length($to) != $l) { die "OOPS $from => $to???"; }
	my %h = ();
	for (my $i = 0; $i < $l; $i++) {
		$h{substr($from, $i, 1)} = substr($to, $i, 1);
	}
	add_h2z(\%h);
}

BEGIN {
	use Encode::JP::H2Z ();
	use utf8;

	# Data borrowed from this module is in EUC-JP and
	# needs to be converted.
	#
	# - %Encode::JP::H2Z:_D2Z maps split-char in H to Z
	# - %Encode::JP::H2Z:_H2Z maps H to Z
	#
	# D2Z needs to be applied first and then H2Z.
	add_h2z(\%Encode::JP::H2Z::_D2Z, 1);
	add_h2z(\%Encode::JP::H2Z::_H2Z, 1);

	# "Violin" and friends.
	add_h2z(+{
		'ヴァ' => 'バ', 'ヴィ' => 'ビ', 'ヴュ' => 'ブ',
		'ヴゥ' => 'ブ',	'ヴェ' => 'べ',	'ヴォ' => 'ボ',
	});
	add_h2z_str('ァィゥェォヵヶ', 'アイウエオカケ');

	# ASCII
	add_h2z_str('０１２３４５６７８９：；＜＝＞？', '0123456789:;<=>?');
	add_h2z_str('＠ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯ', '@ABCDEFGHIJKLMNO');
	add_h2z_str('ＰＱＲＳＴＵＶＷＸＹＺ［￥］＾＿', 'PQRSTUVWXYZ[\\]^_');
	add_h2z_str('ａｂｃｄｅｆｇｈｉｊｋｌｍｎ', 'abcdefghijklmn');
	add_h2z_str('ｐｑｒｓｔｕｖｗｘｙｚ｛｜｝', 'pqrstuvwxyz{|}');
}

sub analyze {
	my $self = shift;
	my (@ascii_token, @all, $text);

	for (@_) {
		# Replace controls to SP -- this takes care of EOL
		# as well.
		s/([\000- ]+)/ /g;

		# Run H2Z for Kana, and stuff.
		s/($H2Z)/(exists $H2Z{$1} ? $H2Z{$1} : $1)/ego;

		# Splice them into ASCII sequence and others,
		# and replace ASCII sequences with stubs.
		while (/^(.*?)([!-~]+)(.*)$/) {
			my ($na, $a, $rest) = ($1, $2, $3);
			$na =~ s/ +//g;
			push @all, $na;
			push @all, (" <<" . scalar(@ascii_token) . ">> ");
			push @ascii_token, $a;
			$_ = $rest;
		}
		if ($_ ne '') {
			# Japanese string.  Remove whitespaces,
			# because a single word could be split
			# across physical lines, in which case we
			# would want to join them back.
			s/ +//g;
			push @all, $_;
		}
	}
	$text = join('', @all);

	return map { encode_utf8($_) }
		$self->handle_morph($text, \@ascii_token);
}

1;
