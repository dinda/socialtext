#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::More;
use utf8;

BEGIN {
	unless ( eval { require Email::Send::Test; 1 } ) {
		plan skip_all => 'These tests require Email::Send::Test to run.';
	}
}

plan tests => 68;

use Socialtext::EmailSender::Factory;
use File::Copy ();
use File::Slurp ();
use File::Temp ();
use URI::Escape ();

use_ok('Socialtext::EmailSender::Factory');

$Socialtext::EmailSender::Base::SendClass = 'Test';

{

	Email::Send::Test->clear();

	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'test1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'test subject',
	   text_body => 'small body',
	);
	my @emails = Email::Send::Test->emails();

	is( scalar @emails, 1, 'one email was sent' );

	is( $emails[0]->header('To'), 'test1@example.com',
		'check To header' );
	is( $emails[0]->header('From'), 'test2@example.com',
		'check From header' );
	is( $emails[0]->header('Subject'), 'test subject',
		'check Subject header' );
	is( $emails[0]->header('Content-Transfer-Encoding'), '7bit',
		'check Content-Transfer-Encoding header' );
	like( $emails[0]->header('Date'), qr/\d+ \w+ \d{4} \d\d:\d\d:\d\d/,
		  'check Date header' );
	like( $emails[0]->header('X-Sender'), qr/Socialtext::EmailSender v.+/,
		  'check Date header' );
	# N.B.: The Message-ID angle brackets aren't optional!
	# See RFC 2822, 3.6.4. -mml 20070504 (thx johnt)
	like( $emails[0]->header('Message-ID'), qr/^\<.*[^@]+\@[^@]+.*\>$/,
		  'check Message-ID header' );
	like( $emails[0]->header('Content-Type'), qr{text/plain},
		  'check Content-Type header' );
	like( $emails[0]->header('Content-Type'), qr{charset="ISO-2022-JP"},
		  'check charset in Content-Type header' );
	is( $emails[0]->body(), "small body", 'check body' );
}

{
	Email::Send::Test->clear();

	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => [ 'test1@example.com', 'test2@example.com' ],
	   subject	 => 'test',
	   text_body => 'small body',
	);

	my @emails = Email::Send::Test->emails();

	is( $emails[0]->header('To'), 'test1@example.com, test2@example.com',
		'check To header for multiple recipients' );
	like( $emails[0]->header('From'), qr/noreply\@socialtext\.com/,
		  'check for default From header' );
}

{
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'test1@example.com',
	   cc		 => 'test2@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'test',
	   text_body => 'small body',
	);

	my @emails = Email::Send::Test->emails();

	is( $emails[0]->header('Cc'), 'test2@example.com',
		'check Cc header' );
}


{
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => [ 'test1@example.com', 'test2@example.com' ],
	   from 	 => 'test2@example.com',
	   subject	 => 'test',
	   text_body => 'small body',
	);

	my @emails = Email::Send::Test->emails();

	is( $emails[0]->header('To'), 'test1@example.com, test2@example.com',
		'check To header for multiple recipients' );
}

{
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'test1@example.com',
	   subject	 => 'test',
	   html_body => '<a href="#">hello</a>',
	);

	my @emails = Email::Send::Test->emails();

	like( $emails[0]->header('Content-Type'), qr{text/html},
		  'check Content-Type header is text/html' );
	like( $emails[0]->header('Content-Type'), qr{charset="ISO-2022-JP"},
		  'check charset in Content-Type header' );
}

TODO:
{
	# Now this is passing for me locally, but I have no clue why! The
	# encoded version still appears to be incorrect.
	local $TODO = 'This will not pass until Encode::MIME::Header is fixed';

	Email::Send::Test->clear();
	binmode STDOUT, ':utf8';
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');


	my $subject = "utf-8 \x80 @! \x{5000}";
	$subject .= 'x x' x 30;

	$email_sender->send(
	   to		 => [ 'test1@example.com', 'test2@example.com' ],
	   subject	 => $subject,
	   text_body => 'small body',
	);
	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('Subject'), $subject,
		'check Subject header which contains utf8 chars' );
}

{
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'test1@example.com',
	   subject	 => 'test',
	   text_body => 'hello',
	   html_body => '<a href="#">hello</a>',
	);

	my @emails = Email::Send::Test->emails();
	like( $emails[0]->header('Content-Type'), qr{multipart/alternative},
		  'check Content-Type header is multipart/alternative' );

	my @parts = $emails[0]->parts;
	like( $parts[0]->header('Content-Type'), qr{text/plain},
		  'first part is text/plain' );
	like( $parts[1]->header('Content-Type'), qr{text/html},
		  'second part is text/html' );
	is( $parts[0]->header('Content-Disposition'), 'inline',
		'first part Content-Disposition is inline' );
	is( $parts[1]->header('Content-Disposition'), 'inline',
		'second part Content-Disposition is inline' );
}

my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
my $hundred_k = "$tempdir/hundred_k.txt";
open my $fh, '>', $hundred_k
	or die $!;
print $fh 'x' x ( 1024 * 100 )
	or die $!;
close $fh or die $!;

my $two_mb = "$tempdir/two_mb.txt";
open $fh, '>', $two_mb
	or die $!;
print $fh 'x' x ( 1024 * 1024 * 2 )
	or die $!;
close $fh or die $!;

my $four_mb = "$tempdir/four_mb.txt";
open $fh, '>', "$tempdir/four_mb.txt"
	or die $!;
print $fh 'x' x ( 1024 * 1024 * 4 )
	or die $!;
close $fh or die $!;

my $image = "$tempdir/socialtext-logo-30.gif";
File::Copy::copy( 't/attachments/socialtext-logo-30.gif', $tempdir )
	or die $!;

{
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		   => 'test1@example.com',
	   subject	   => 'test',
	   text_body   => 'hello',
	   attachments => [ $hundred_k, $two_mb, $four_mb, $image ],
	);

	my @emails = Email::Send::Test->emails();
	like( $emails[0]->header('Content-Type'), qr{^multipart/mixed},
		  'Content-Type is multipart/mixed when we have attachments' );

	my @parts = $emails[0]->parts;
	my @att = @parts[1..$#parts];

	is( scalar @att, 3, 'three attachments' );
	like( $att[0]->header('Content-Type'), qr{text/plain},
		  'Content-Type for first attachment' );
	like( $att[1]->header('Content-Type'), qr{text/plain},
		  'Content-Type for second attachment' );
	like( $att[2]->header('Content-Type'), qr{image/gif},
		  'Content-Type for third attachment' );

	is( $att[2]->body, File::Slurp::read_file($image),
		'image in attachment matches original' );

	ok( ( ! grep { $_->filename eq 'four_mb.txt' } @att ),
		'four_mb.txt was not included in attachments' );
}

{
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		   => 'test1@example.com',
	   subject	   => 'test',
	   text_body   => 'hello',
	   attachments => [ $two_mb, $four_mb ],
	   max_size    => 0,
	);

	my @emails = Email::Send::Test->emails();
	my @parts = $emails[0]->parts;
	my @att = @parts[1..$#parts];

	is( scalar @att, 2, 'two attachments' );
}

{
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		   => 'test1@example.com',
	   subject	   => 'test',
	   text_body   => 'hello',
	   html_body   => '<b>hello</b>',
	   attachments => [ $hundred_k ],
	);

	my @emails = Email::Send::Test->emails();
	like( $emails[0]->header('Content-Type'), qr{^multipart/mixed},
		  'text + html + attachments Content-Type is multipart/mixed' );

	my @parts = $emails[0]->parts;
	like( $parts[0]->header('Content-Type'), qr{^multipart/alternative},
		  'first part Content-Type is multipart/alternative' );

	my @subparts = $parts[0]->parts;
	like( $subparts[0]->header('Content-Type'), qr{^text/plain},
		  'first subpart of mp/alt part Content-Type is text/plain' );
	like( $subparts[1]->header('Content-Type'), qr{^text/html},
		  'second subpart of mp/alt part Content-Type is text/html' );

	my @att = @parts[1..$#parts];

	is( scalar @att, 1, 'one attachment' );
}

{
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		   => 'test1@example.com',
	   subject	   => 'test',
	   html_body   => 'has an image <img src="cid:socialtext-logo-30.gif" />',
	   attachments => [ $image ],
	);

	my @emails = Email::Send::Test->emails();
	like( $emails[0]->header('Content-Type'), qr{^multipart/related},
		  'html + image attachment & img tag in source Content-Type is multipart/related' );
	like( $emails[0]->header('Content-Type'), qr{type="text/html"},
		  'html + image attachment & img tag in source Content-Type specifies first related part type as text/html' );

	my @parts = $emails[0]->parts;
	like( $parts[0]->header('Content-Type'), qr{^text/html},
		  'first part Content-Type is text/html' );
	like( $parts[1]->header('Content-Type'), qr{^image/gif},
		  'second part Content-Type is image/gif' );
}

TO_IS_ASCII: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'test <test1@example.com>',
	   from 	 => 'test2@example.com',
	   subject	 => 'TO_IS_ASCII',
	   text_body => 'check the to-address',
	);

	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('To'), 'test <test1@example.com>',
		'check To header' );
}

TO_IS_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => '日本人 <test1@example.com>',
	   from 	 => 'test2@example.com',
	   subject	 => 'TO_IS_JAPANESE',
	   text_body => 'check the to-address.',
	);

	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('To'), '日本人 <test1@example.com>',
		'check To header' );
}

TO_IS_OVER_80_JAPANESE_SINGLE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ <test1@example.com>',
	   from 	 => 'test2@example.com',
	   subject	 => 'TO_IS_OVER_80_JAPANESE_SINGLE',
	   text_body => 'check the to-addresses',
	);

	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('To'), 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ <test1@example.com>',
		'check To header' );
}

TO_IS_OVER_80_JAPANESE_MULTI: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ <test1@example.com>,' . '亜伊卯江尾亜伊卯江尾 <test3@example.com>',
	   from 	 => 'test2@example.com',
	   subject	 => 'TO_IS_OVER_80_JAPANESE_MULTI',
	   text_body => 'check the to-addresses',
	);

	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('To'), 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ <test1@example.com>,' . '亜伊卯江尾亜伊卯江尾 <test3@example.com>',
		'check To header' );
}

CC_IS_ASCII: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'test@example.com',
	   cc		 => 'cc1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'CC_IS_ASCII',
	   text_body => 'check the cc-address.',
	);
	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('Cc'), 'cc1@example.com',
		'check Cc header' );
}

CC_IS_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'test@example.com',
	   cc		 => '日本人 <cc1@example.com>',
	   from 	 => 'test2@example.com',
	   subject	 => 'CC_IS_JAPANESE',
	   text_body => 'check the cc-address.',
	);
	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('Cc'), '日本人 <cc1@example.com>',
		'check Cc header' );
}

CC_IS_OVER_80_JAPANESE_SINGLE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'test@example.com',
	   cc		 => 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ <cc1@example.com>',
	   from 	 => 'test2@example.com',
	   subject	 => 'CC_IS_OVER_80_JAPANESE_SINGLE',
	   text_body => 'check the to-addresses',
	);
	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('Cc'), 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ <cc1@example.com>',
		'check Cc header' );
}

CC_IS_OVER_80_JAPANESE_MULTI: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'test@example.com',
	   cc		 => 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ <cc1@example.com>,' . '亜伊卯江尾亜伊卯江尾 <cc1@example.com>',
	   from 	 => 'test2@example.com',
	   subject	 => 'CC_IS_OVER_80_JAPANESE_MULTI',
	   text_body => 'check the to-addresses',
	);
	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('Cc'), 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ <cc1@example.com>,' . '亜伊卯江尾亜伊卯江尾 <cc1@example.com>',
		'check Cc header' );
}

FROM_IS_ASCII: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'from1@example.com',
	   subject	 => 'FROM_IS_ASCII',
	   text_body => 'test',
	);
	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('From'), 'from1@example.com',
		'check From header' );
}

FROM_IS_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => '日本人 <from1@example.com>',
	   subject	 => 'FROM_IS_JAPANESE',
	   text_body => 'test',
	);
	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('From'), '日本人 <from1@example.com>',
		'check From header' );
}

FROM_IS_OVER_80_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ <from1@example.com>',
	   subject	 => 'FROM_IS_OVER_80_JAPANESE',
	   text_body => 'test',
	);
	my @emails = Email::Send::Test->emails();
	is( $emails[0]->header('From'), 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ <from1@example.com>',
		'check From header' );
}

TEXTBODY_IS_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'TEXTBODY_IS_JAPANESE',
	   text_body => 'テキストボディ～終',
	);

	my @emails = Email::Send::Test->emails();
	my $body = Encode::decode('ISO-2022-JP', $emails[0]->body());
	is( $body, 'テキストボディ〜終', 'check body' );
}

HTMLBODY_IS_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'HTMLBODY_IS_JAPANESE',
	   html_body => '<a href="#">ＨＴＭＬボディ</a>',
	);
	my @emails = Email::Send::Test->emails();
	my $body = Encode::decode('ISO-2022-JP', $emails[0]->body());
	is( $body, '<a href="#">ＨＴＭＬボディ</a>', 'check body' );
}

SUBJECT_AND_BODY_IS_HANKAKU: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'HANKAKU_日本語ﾀｲﾄﾙ',
	   text_body => 'ﾃｷｽﾄﾎﾞﾃﾞｨ～終',
	);
	my @emails = Email::Send::Test->emails();
	my $body = Encode::decode('ISO-2022-JP', $emails[0]->body());
	is( $body, 'テキストボディ〜終', 'check body' );
}

my $hundred_k_jp = "$tempdir/" . URI::Escape::uri_escape_utf8("１００ＫＢサイズ.txt");
open  $fh, '>', $hundred_k_jp
	or die $!;
print $fh 'x' x ( 1024 * 100 )
	or die $!;
close $fh or die $!;

my $image_jp = "$tempdir/" . URI::Escape::uri_escape_utf8("ソーシャルテキストのロゴ.gif");
open $fh, '>', $image_jp
	or die $!;
print $fh 'x' x ( 1024 * 10 )
	or die $!;
close $fh or die $!;


my $ppt_jp = "$tempdir/" . URI::Escape::uri_escape_utf8("パワーポイント.ppt");
open $fh, '>', $ppt_jp
	or die $!;
print $fh 'x' x ( 1024 * 100 )
	or die $!;
close $fh or die $!;

THREE_ATTACHMENTS_ARE_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'THREE_ATTACHMENTS_ARE_JAPANESE',
	   text_body => 'check the attachments.',
	   attachments => [ $hundred_k_jp, $image_jp, $ppt_jp ],
	);

	my @emails = Email::Send::Test->emails();							  
	like( $emails[0]->header('Content-Type'), qr{^multipart/mixed}, 	  
		  'Content-Type is multipart/mixed when we have attachments' );   
																		  
	my @parts = $emails[0]->parts;								 
	my @att = @parts[1..$#parts];								 
																 
	is( scalar @att, 3, 'three attachments' );					 
	like( $att[0]->header('Content-Type'), qr{text/plain},		 
		  'Content-Type for first attachment' );				 
	like( $att[1]->header('Content-Type'), qr{image/gif},		
		  'Content-Type for second attachment' );				 
	like( $att[2]->header('Content-Type'), qr{application/vnd.ms-powerpoint},
		  'Content-Type for third attachment' );				 
}

TEXT_OVER_1000_ASCII: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');
	
	my $text_body = '0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789a';
	
	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'TEXT_OVER_1000_ASCII',
	   text_body => $text_body,
   );

   my @emails = Email::Send::Test->emails();							 
   my $body = Encode::decode('ISO-2022-JP', $emails[0]->body());
   is( $body,  $email_sender->_fold_body($text_body), 'check body' );
}

TWO_TEXT_OVER_1000_ASCII: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');
	
	my $test_body = "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789a" . "\n" . "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789a";
	
	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'TWO_TEXT_OVER_1000_ASCII',
	   text_body => $test_body,
   );
   my @emails = Email::Send::Test->emails();							 
   my $body = Encode::decode('ISO-2022-JP', $emails[0]->body());
   is( $body,  $email_sender->_fold_body($test_body), 'check body' );
}

TEXT_OVER_1000_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');
	
	my $test_body = 'あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえお かきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ〜';
	
	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'TEXT_OVER_1000_JAPANESE',
	   text_body => $test_body
	   );

   my @emails = Email::Send::Test->emails();							 
   my $body = Encode::decode('ISO-2022-JP', $emails[0]->body());
   is( $body,  $email_sender->_fold_body($test_body), 'check body' );
}




HTML_OVER_1000_ASCII: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	my $test_body = '<a href=#>0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789a</a>';
	
	$email_sender->send(
		to		  => 'to1@example.com',
		from	  => 'test2@example.com',
		subject   => 'HTML_OVER_1000_ASCII',
		html_body => $test_body,
   );
	my @emails = Email::Send::Test->emails();							  
	my $body = Encode::decode('ISO-2022-JP', $emails[0]->body());

	is( $body,	$email_sender->_fold_body($test_body), 'check body' );
}

HTML_OVER_1000_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');
	
	my $test_body = '<p>あいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこあいうえおかきくけこ〜</p>';
	
	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'HTML_OVER_1000_JAPANESE',
	   html_body => $test_body,
   );
	my @emails = Email::Send::Test->emails();
	my $body = Encode::decode('ISO-2022-JP', $emails[0]->body());
	is( $body,	$email_sender->_fold_body($test_body), 'check body' );

}

SUBJECT_IS_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => '日本語タイトル',
	   text_body => 'hello',
	);
	my @emails = Email::Send::Test->emails();
	my $subject = Encode::decode('ISO-2022-JP', $emails[0]->header('Subject'));
	is ( $subject, '日本語タイトル', 'check the subject' );
}

SUBJECT_OVER_80_JAPANESE: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
	   to		 => 'to1@example.com',
	   from 	 => 'test2@example.com',
	   subject	 => 'あいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえお終',
	   text_body => 'check the subject',
   );
	my @emails = Email::Send::Test->emails();
	my $subject = Encode::decode('ISO-2022-JP', $emails[0]->header('Subject'));
	is ( $subject, 'あいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえおあいうえお終', 'check the subject' );

}

SUBJECT_INCLUDE_EN_JA: {
	Email::Send::Test->clear();
	my $email_sender = Socialtext::EmailSender::Factory->create('ja');

	$email_sender->send(
		to		  => 'to1@example.com',
		from	  => 'test2@example.com',
		subject   => 'helloこんにちは ～　こんにちは ～',
		text_body => 'SUBJECT_INCLUDE_EN_JA', 
	);
	my @emails = Email::Send::Test->emails();
	my $subject = Encode::decode('ISO-2022-JP', $emails[0]->header('Subject'));
	is ( $subject, 'helloこんにちは 〜　こんにちは 〜', 'check the subject' );
}


use Lingua::JA::Fold;
use Encode		   ();

sub fold_body {
	my $self	= shift;
	my $body	= shift; 
	# fold line over 989bytes because some smtp server chop line over 989
	# bytes and this causes mojibake
	Encode::_utf8_on($body) unless Encode::is_utf8($body);

	my $folded_body;
	my $line_length;
	my @lines = split /\n/, $body;
	foreach my $line (@lines) {
		{
			use bytes;
			$line_length = length($line);
		}
		if($line_length > 988) {
			$line = fold( 'text' => $line, 'length' => 300 );
		}
		
		$folded_body .= $line;
		if(@lines > 1) {
			$folded_body .= "\n";
		}
	}
	$body = $folded_body;
	return $body; 
}


