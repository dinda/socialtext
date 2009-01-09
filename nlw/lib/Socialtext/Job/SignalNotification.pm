package Socialtext::Job::SignalNotification;
use strict;
use warnings;
use base qw( TheSchwartz::Worker );
use Socialtext::Log qw/st_log/;
use Email::Send;
use Email::Simple;
use Socialtext::SQL qw/sql_execute/;

sub work {
    my $class                = shift;
    my TheSchwartz::Job $job = shift;
    my $args                 = $job->arg;

    for my $nick (@{ $args->{nicks} }) {
        st_log()->info("Sending signal notification to $nick");

        my $sth = sql_execute(<<EOT, $nick);
SELECT user_id 
    FROM profile_attribute 
        JOIN profile_field USING (profile_field_id)
    WHERE name = 'twitter_sn' AND value = ?
EOT
        for my $uid (map { $_->[0] } @{ $sth->fetchall_arrayref }) {
            eval { _email_user( $uid, $args->{signal} ) };
            st_log()->error("Error emailing user: $@") if $@;
        }

    }

    $job->completed();
}

sub _email_user {
    my $uid   = shift;
    my $sig   = shift;

    require Socialtext::User;
    my $user = Socialtext::User->new( user_id => $uid );
    die "Couldn't find user $uid: $!" unless $user;

    my $recipient = $user->email_address;
    $recipient = 'luke.closs@socialtext.com';
    st_log()->info("Mapped $uid to user_id $recipient");

    my $email_body = <<EOT;
To: $recipient
From: "Socialtext" <noreply\@socialtext.com>
Subject: You were mentioned in a signal

You were mentioned in a signal by $sig->{best_full_name} at $sig->{at}.

> $sig->{body}

EOT

    my $msg = Email::Simple->new( $email_body );
    my $sender = Email::Send->new( {mailer =>'SMTP'} );
    $sender->send( $msg );
}

1;
