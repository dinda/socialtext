package Socialtext::Job::WebHook;
use strict;
use warnings;
use base qw( TheSchwartz::Worker );
use LWP::UserAgent;
use Socialtext::JSON qw/encode_json decode_json/;
use Socialtext::Log qw/st_log/;

sub work {
    my $class = shift;
    my TheSchwartz::Job $job = shift;

    my $ua = LWP::UserAgent->new;
    $ua->agent('Socialtext/WebHook');

    my $args = $job->arg;
    $args->{event}{context} = decode_json($args->{event}{context});
    my $response = $ua->post( $args->{hook}{url},
        { payload => encode_json($args->{event}) },
    );

    st_log()->info("Triggered webhook '$args->{hook}{id}': "
                    . $response->status_line);
    $job->completed();
}

1;
