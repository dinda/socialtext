package Socialtext::Schwartz;
use strict;
use warnings;
use Socialtext::Schema;
use Socialtext::SQL qw/sql_execute/;
use TheSchwartz;
use base 'Exporter';
our @EXPORT_OK = qw/work_asynchronously list_jobs clear_jobs client/;
use Socialtext::Job::WebHook;

our $Schwartz;
sub client {
    return $Schwartz if $Schwartz;

    my %params = Socialtext::Schema->connect_params();
    my $client = TheSchwartz->new( 
        databases => [
            {
                dsn => "dbi:Pg:database=$params{db_name}",
                user => $params{user},
            },
        ],
    );
    return $Schwartz = $client;
}

sub work_asynchronously {
    my $job_class = "Socialtext::Job::" . (shift || die 'Need class name');
    my %args = @_;

    my $client = client();
    $client->insert($job_class, \%args);
}

sub list_jobs {
    my %args = @_;
    $args{funcname} = "Socialtext::Job::$args{funcname}";
    my $client = client();
    return $client->list_jobs( \%args );
}

sub clear_jobs {
    sql_execute('DELETE FROM job');
}

1;
