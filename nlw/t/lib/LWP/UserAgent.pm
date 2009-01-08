package LWP::UserAgent;
# @COPYRIGHT@
use strict;
use warnings;
use HTTP::Response;

our $VERSION = 3.0;
our %RESULTS;
our %POST_ARGS;

sub new {
    my ($class, %args) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub agent {
    my ($self, $agent_string) = @_;
    return $self->{_agent} = $agent_string;
}

sub get {
    my ($self, $url) = @_;
    return HTTP::Response->new($RESULTS{$url});
}

sub post {
    my ($self, $url, $args) = @_;

    push @{ $POST_ARGS{$url} }, $args;
    return HTTP::Response->new($RESULTS{$url});
}

1;
