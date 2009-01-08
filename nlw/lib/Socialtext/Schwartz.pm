package Socialtext::Schwartz;
use strict;
use warnings;
use Socialtext::Schema;
use TheSchwartz;
use base 'Exporter';
our @EXPORT_OK = qw/work_asynchronously list_jobs/;

our $Schwartz;
sub _schwartz {
    return $Schwartz if $Schwartz;

    my %params = Socialtext::Schema->connect_params();
    my $client = TheSchwartz->new( 
        databases => [
            {
                dsn => "dbi:Pg:database=$params{db_name}",
                user => $params{user},
            },
        ],
        verbose => 1,
    );
    return $Schwartz = $client;
}

sub work_asynchronously {
    my $job_class = shift;
    my %args = @_;

    my $client = _schwartz();
    $client->insert($job_class, \%args);
}

sub list_jobs {
    my %args = @_;
    my $client = _schwartz();
    return $client->list_jobs( \%args );
}

1;
