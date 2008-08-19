package Socialtext::MassAdd;
# @COPYRIGHT@
use strict;
use warnings;
use Text::CSV_XS;
use Socialtext::Log qw(st_log);
use Socialtext::User;
use Socialtext::l10n qw/loc/;

our $Has_People_Installed;

BEGIN {
    eval "require Socialtext::People::Profile";
    $Has_People_Installed = !$@;
}

sub users {
    my $class   = shift;
    my %opts    = @_;
    my $csv     = delete $opts{csv}     or die "csv is mandatory!";
    my $pass_cb = delete $opts{pass_cb} or die "pass_cb is mandatory!";
    my $fail_cb = delete $opts{fail_cb} or die "fail_cb is mandatory!";

    my @lines = split "\n", $csv;
    my @profile_fields
        = qw/position company location work_phone mobile_phone home_phone/;
    my @user_fields = qw/first_name last_name password/;
    my $parser = Text::CSV_XS->new();
    my $line = 0;
  LINE:
    for my $user_record (@lines) {
        $line++;

        # parse the next line, choking if its not valid.
        my $parsed_ok = $parser->parse($user_record);
        unless ($parsed_ok) {
            my $msg = loc("Line [_1]: could not be parsed.  Skipping this user.", $line);
            st_log->error($msg);
            $fail_cb->($msg);
            next LINE;
        }

        # extract field data from the parsed line
        my ($username, $email, $first_name, $last_name, $password, @profile)
            = map { defined $_ ? $_ : '' } $parser->fields();
        my @userdata = ($first_name, $last_name, $password);

        # sanity check the parsed data, to make sure that fields we *know* are
        # required are really present
        unless ($username) {
            my $msg = loc("Line [_1]: [_2] is a required field, but it is not present.", $line, 'username');
            st_log->error($msg);
            $fail_cb->($msg);
            next LINE;
        }
        unless ($email) {
            my $msg = loc("Line [_1]: [_2] is a required field, but it is not present.", $line, 'email');
            st_log->error($msg);
            $fail_cb->($msg);
            next LINE;
        }
        if (length($password)) {
            my $result
                = Socialtext::User->ValidatePassword(password => $password);
            if ($result) {
                my $msg = loc("Line [_1]: [_2]", $line, $result);
                st_log->error($msg);
                $fail_cb->($msg);
                next;
            }
        }

        # see if we've got an existing record for this user, and add/update as
        # necessary.
        my $user;
        my $changed_user = 0;
        my $added_user = 0;
        eval { $user = Socialtext::User->Resolve($username) };
        unless ($user) {
            eval {
                $user = Socialtext::User->create(
                    username      => $username,
                    email_address => $email,
                    password      => $password,
                    first_name    => $first_name,
                    last_name     => $last_name,
                );
                $added_user++;
            };
            my $err = $@;
            if ($err and $err =~ m/is not a valid email address/) {
                my $msg = loc("Line [_1]: [_2]", $line, loc("email is a required field, but could not be parsed."));
                st_log->error($msg);
                $fail_cb->($msg);
                next;
            }
            elsif ($err) {
                die $err;
            }

            # Send the user a confirmation email, if they don't have a pw
            unless ( $user->has_valid_password ) {
                $user->set_confirmation_info( is_password_change => 0 );
                $user->send_confirmation_email();
            }
        }

        if ($user->can_update_store) {
            for (my $i = 0; $i < @user_fields; $i++) {
                my $field = $user_fields[$i];
                my $value = $userdata[$i];
                if (length($userdata[$i]) and $user->$field ne $value) {
                    $user->update_store( $field => $value );
                    $changed_user++;
                }
            }
        }

        if ($Has_People_Installed) {
            my $p = Socialtext::People::Profile->GetProfile($user, 1);
            for (my $i = 0; $i < @profile_fields; $i++) {
                my $value = $profile[$i];
                next unless $value;
                my $field = $profile_fields[$i];
                next if ($p->$field() || '') eq $value;
                $p->$field($value);
                $changed_user++;
            }
            $p->save() if ($changed_user);
        }
        if ($added_user) {
            my $msg = loc("Added user [_1]", $username);
            st_log->info($msg);
            $pass_cb->($msg);
        }
        elsif ($changed_user) {
            my $msg = loc("Updated user [_1]", $username);
            st_log->info($msg);
            $pass_cb->($msg);
        }
    }
}

1;
