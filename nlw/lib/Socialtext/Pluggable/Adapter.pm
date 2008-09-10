package Socialtext::Pluggable::Adapter;
# @COPYRIGHT@
use strict;
use warnings;

our @libs;
our $AUTOLOAD;
my %hooks;

use base 'Socialtext::Plugin';
use Socialtext::Workspace;
use Fcntl ':flock';
use File::chdir;
use Module::Pluggable search_path => ['Socialtext::Pluggable::Plugin'],
                      search_dirs => \@libs;
use Socialtext::Pluggable::WaflPhrase;
use Socialtext::SQL qw/sql_singlevalue/;
use Socialtext::User::Default::Factory qw($SystemUsername $GuestUsername);

# These hook types are executed only once, all other types are called as many
# times as they are registered
my %ONCE_TYPES = (
    action => 1,
    wafl => 1,
    template => 1,
);

BEGIN {
    # This is still needed for dev-env -- Do Not Delete!
    our $code_base = Socialtext::AppConfig->code_base;
    push @INC, glob("$code_base/plugin/*/lib");
}

sub AUTOLOAD {
    my ($self,$rest_handler,$args) = @_;
    my $type = ref($self)
        or die "$self is not an object in " . __PACKAGE__ . "\n";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    # strip fully-qualified portion
    return if $name eq 'DESTROY';
    
    my ($hook_name) = $name =~ /_rest_hook_(.*)/;
    die "Not a REST hook call '$name'\n" unless $hook_name;

    $self->make_hub($rest_handler->user);

    $self->{_rest_handler} = $rest_handler;

    return $self->hook($hook_name, $args);
}

sub handler {
    my ($self, $rest) = @_;
    my $t = time;

    $self->make_hub($rest->user) unless $self->hub;

    if ($rest->query->param('action')) {
        my $res = $self->hub->process;
        $rest->header(-type => 'text/html; charset=UTF-8', # default
                      $self->hub->rest->header);
        return $res;
    }
    else {
        my $res = $self->hook('root', $rest);
        $rest->header($self->hub->rest->header);
        return $res;
    }
}

sub make_hub {
    my ($self,$user,$ws) = @_;
    my $main = Socialtext->new;
    $main->load_hub(
        current_user => $user,
        current_workspace => $ws || Socialtext::NoWorkspace->new,
    );
    $main->hub->registry->load;
    $main->debug;
    $self->hub( $self->{made_hub} = $main->hub );
}

sub class_id { 'pluggable' };
sub class_title { 'Pluggable' };

for my $plugin (__PACKAGE__->plugins) {
    eval "require $plugin";
    die $@ if $@;
    $plugin->register;

    for my $hook ($plugin->rest_hooks) {
        push @{$hooks{$hook->{name}}}, $hook;
    }
}

sub make {
    my $class = shift;
    my $dir = Socialtext::File::catdir(
        Socialtext::AppConfig->code_base(),
        'plugin',
    );
    for my $plugin ($class->plugins) {
        my $name = $plugin->name;
        local $CWD = "$dir/$name";
        next unless -f 'Makefile';

        my $semaphore = "$dir/build-semaphore";
        open( my $lock, ">>", $semaphore )
            or die "Could not open $semaphore: $!\n";
        flock( $lock, LOCK_EX )
            or die "Could not get lock on $semaphore: $!\n";
        system( 'make', 'all' ) and die "Error calling make in $dir/$name: $!";
        close($lock);
    }
}

sub rest_hooks {
    my $class = shift;
    my @rest_hooks;
    for my $plugin ($class->plugins) {
        push @rest_hooks, $plugin->rests;
    }
    return @rest_hooks;
}

sub register {
    my ($self,$registry) = @_;

    my @plugins = sort { $b->priority <=> $a->priority }
                  $self->plugins;

    for my $plugin (@plugins) {
        for my $hook ($plugin->hooks) {
            my ($type, @parts) = split /\./, $hook->{name};


            if ($type eq 'wafl') {
                $registry->add(
                    'wafl', $parts[0], 'Socialtext::Pluggable::WaflPhrase',
                );
            }
            elsif ($type eq 'action') {
                no strict 'refs';
                my $class = ref $self;
                my $action = $parts[0];
                my $sub = "${class}::$action";

                *{$sub} = sub { return $_[0]->hook($hook->{name}) };
                $registry->add(action => $action);
            }

            $hook->{once} = 1 if $ONCE_TYPES{$type};

            push @{$hooks{$hook->{name}}}, $hook;
        }
    }

    $self->hook('nlw.start');
}

sub plugin_list {
    my ($class_or_self, $name) = @_;
    return map { $_->name } $class_or_self->plugins;
}

sub plugin_exists {
    my ($class_or_self, $name) = @_;
    my %list = map { $_ => 1 } $class_or_self->plugin_list;
    return $list{$name};
}

sub registered {
    my ($self, $name) = @_;
    return exists $hooks{$name};
}

sub hook {
    my ( $self, $name, @args ) = @_;
    my @output;
    if ( my $hooks = $hooks{$name} ) {
        return unless ref $hooks eq 'ARRAY';
        for my $hook (@$hooks) {
            my $method = $hook->{method};
            my $plugin = $hook->{obj} ||= $hook->{class}->new();
            my $hub = $self->hub || $self->{made_hub};

            my $enabled = $hub->current_user->can_use_plugin($plugin->name);
                         
            if ($enabled) {
                $hook->{obj}->hub($hub);
                $hook->{obj}->rest( delete $self->{_rest_handler} );
                push @output, $hook->{obj}->$method(@args);
                last if $hook->{once};
            }
        }
    }
    return join("\n", @output);
}

sub PluginEnabledForUser {
    my ($class, $plugin_name, $user) = @_;

    return 0 unless $class->plugin_exists($plugin_name);

    return 1 if ($user->username eq $SystemUsername);

    my $enabled = sql_singlevalue(<<SQL, $user->user_id, $plugin_name);
        SELECT 1 FROM user_account
        WHERE system_unique_id = ?
          AND EXISTS (
            SELECT 1 
            FROM account_plugin 
            WHERE plugin = ? AND (
                account_id = primary_account_id OR
                account_id = secondary_account_id
            )
          )
        LIMIT 1
SQL
    return $enabled;
}

return 1;
