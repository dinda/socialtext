package Socialtext::Schwartz;
use strict;
use warnings;
use Socialtext::Schema;
use Socialtext::SQL qw/sql_execute/;
use TheSchwartz;
use base 'Exporter';
our @EXPORT_OK = qw/work_asynchronously list_jobs clear_jobs work/;
use Socialtext::Job::WebHook;

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
    my $job_class = "Socialtext::Job::" . (shift || die 'Need class name');
    my %args = @_;

    my $client = _schwartz();
    $client->insert($job_class, \%args);
}

sub list_jobs {
    my %args = @_;
    $args{funcname} = "Socialtext::Job::$args{funcname}";
    my $client = _schwartz();
    return $client->list_jobs( \%args );
}

sub clear_jobs {
    sql_execute('DELETE FROM job');
}

sub work {
    my $once = shift;

    my $client = _schwartz();
    $client->can_do( 'Socialtext::Job::WebHook' );

    if ($once) {
        $client->work_once;
    }
    else {
        $client->work;
    }
}

1;
