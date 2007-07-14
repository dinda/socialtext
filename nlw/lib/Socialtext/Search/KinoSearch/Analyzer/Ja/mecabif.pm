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

sub canonify {
	my ($string) = @_;
	for ($string) {
		use utf8;

		s/ｶﾞ/ガ/g; s/ｷﾞ/ギ/g; s/ｸﾞ/グ/g; s/ｹﾞ/ゲ/g; s/ｺﾞ/ゴ/g;
		s/ｻﾞ/ザ/g; s/ｼﾞ/ジ/g; s/ｽﾞ/ズ/g; s/ｾﾞ/ゼ/g; s/ｿﾞ/ゾ/g;
		s/ﾀﾞ/ダ/g; s/ﾁﾞ/ヂ/g; s/ﾂﾞ/ヅ/g; s/ﾃﾞ/デ/g; s/ﾄﾞ/ド/g;
		s/ﾊﾞ/バ/g; s/ﾋﾞ/ビ/g; s/ﾌﾞ/ブ/g; s/ﾍﾞ/ベ/g; s/ﾎﾞ/ボ/g;
		s/ﾊﾟ/パ/g; s/ﾋﾟ/ピ/g; s/ﾌﾟ/プ/g; s/ﾍﾟ/ペ/g; s/ﾎﾟ/ポ/g;
		s/ｳﾞ/ヴ/g;

		s/ｧ/ァ/g; s/ｨ/ィ/g; s/ｩ/ゥ/g; s/ｪ/ェ/g; s/ｫ/ォ/g; 
		s/ｬ/ャ/g; s/ｭ/ュ/g; s/ｮ/ョ/g; s/ｯ/ッ/g; s/ｰ/ー/g;
		s/ｱ/ア/g; s/ｲ/イ/g; s/ｳ/ウ/g; s/ｴ/エ/g; s/ｵ/オ/g;
		s/ｶ/カ/g; s/ｷ/キ/g; s/ｸ/ク/g; s/ｹ/ケ/g; s/ｺ/コ/g;
		s/ｻ/サ/g; s/ｼ/シ/g; s/ｽ/ス/g; s/ｾ/セ/g; s/ｿ/ソ/g;
		s/ﾀ/タ/g; s/ﾁ/チ/g; s/ﾂ/ツ/g; s/ﾃ/テ/g; s/ﾄ/ト/g;
		s/ﾅ/ナ/g; s/ﾆ/ニ/g; s/ﾇ/ヌ/g; s/ﾈ/ネ/g; s/ﾉ/ノ/g;
		s/ﾊ/ハ/g; s/ﾋ/ヒ/g; s/ﾌ/フ/g; s/ﾍ/ヘ/g; s/ﾎ/ホ/g;
		s/ﾏ/マ/g; s/ﾐ/ミ/g; s/ﾑ/ム/g; s/ﾒ/メ/g; s/ﾓ/モ/g;
		s/ﾔ/ヤ/g; s/ﾕ/ユ/g; s/ﾖ/ヨ/g;
		s/ﾗ/ラ/g; s/ﾘ/リ/g; s/ﾙ/ル/g; s/ﾚ/レ/g; s/ﾛ/ロ/g;
		s/ﾜ/ワ/g; s/ｦ/ヲ/g; s/ﾝ/ン/g;
		s/｡/。/g; s/｢/「/g; s/｣/」/g; s/､/、/g; s/･/・/g;
		s/ﾞ/゛/g; s/ﾟ/゜/g;

		s/　/\ /g;
		s/０/0/g;	s/１/1/g;	s/２/2/g;	s/３/3/g;
		s/４/4/g;	s/５/5/g;	s/６/6/g;	s/７/7/g;
		s/８/8/g;	s/９/9/g;

		s/Ａ/A/g;	s/Ｂ/B/g;	s/Ｃ/C/g;	s/Ｄ/D/g;
		s/Ｅ/E/g;	s/Ｆ/F/g;	s/Ｇ/G/g;	s/Ｈ/H/g;
		s/Ｉ/I/g;	s/Ｊ/J/g;	s/Ｋ/K/g;	s/Ｌ/L/g;
		s/Ｍ/M/g;	s/Ｎ/N/g;	s/Ｏ/O/g;	s/Ｐ/P/g;
		s/Ｑ/Q/g;	s/Ｒ/R/g;	s/Ｓ/S/g;	s/Ｔ/T/g;
		s/Ｕ/U/g;	s/Ｖ/V/g;	s/Ｗ/W/g;	s/Ｘ/X/g;
		s/Ｙ/Y/g;	s/Ｚ/Z/g;

		s/ａ/a/g;	s/ｂ/b/g;	s/ｃ/c/g;	s/ｄ/d/g;
		s/ｅ/e/g;	s/ｆ/f/g;	s/ｇ/g/g;	s/ｈ/h/g;
		s/ｉ/i/g;	s/ｊ/j/g;	s/ｋ/k/g;	s/ｌ/l/g;
		s/ｍ/m/g;	s/ｎ/n/g;	s/ｏ/o/g;	s/ｐ/p/g;
		s/ｑ/q/g;	s/ｒ/r/g;	s/ｓ/s/g;	s/ｔ/t/g;
		s/ｕ/u/g;	s/ｖ/v/g;	s/ｗ/w/g;	s/ｘ/x/g;
		s/ｙ/y/g;	s/ｚ/z/g;

		s/ヴァ/バ/g;	s/ヴィ/ビ/g;	s/ヴュ/ブ/g;	s/ヴゥ/ブ/g;
		s/ヴェ/べ/g;	s/ヴォ/ボ/g;

		s/ァ/ア/g;	s/ィ/イ/g;	s/ゥ/ウ/g;	s/ェ/エ/g;
		s/ォ/オ/g;	s/ヵ/カ/g;	s/ヶ/ケ/g;

	}
	return $string;
}

sub analyze {
	my $self = shift;
	my (@ascii_token, @all, $text);

	for (@_) {
		# Replace controls to SP -- this takes care of EOL
		# as well.
		s/([\000- ]+)/ /g;

		# Run H2Z for Kana, and stuff.
		$_ = canonify($_);
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
