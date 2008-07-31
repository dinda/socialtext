package Socialtext::Handler::Authen;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Handler';

use Apache::Constants qw( NOT_FOUND );
use Socialtext;

use Email::Valid;
use Exception::Class;
use Socialtext::AppConfig;
use Socialtext::Authen;
use Socialtext::Log 'st_log';
use Socialtext::Apache::User;
use Socialtext::User;
use Socialtext::Session;
use Socialtext::Helpers;
use Socialtext::l10n qw( loc loc_lang system_locale );
use URI::Escape qw(uri_escape_utf8);

sub handler ($$) {
    my $class = shift;
    my $r     = shift;

    my $self = bless {r => $r}, __PACKAGE__; # new can kiss my ass
    $self->{args} = { $r->args, $r->content };

    loc_lang( system_locale() );

    (my $uri = $r->uri) =~ s[^/nlw/?][];
    if ($uri =~ m[submit/]) {
        my ($action) = $uri =~ m[submit/(\w+)];
        
        return $self->$action if $self->can($action);
        warn "Can't handle action '$action'";
        return NOT_FOUND;
    } 
    elsif ($uri =~ /\.html$/) {
        # strip off trailing ; to avoid warning
        (my $query_string = $r->args || '') =~ s/;$//;
        $r->args($query_string);

        my $saved_args = $self->{saved_args} = $self->session->saved_args;
        my $vars     = {
            loc            => \&loc,
            errors         => [ $self->session->errors ],
            messages       => [ $self->session->messages ],
            username_label => $self->username_label,
            redirect_to    => $self->{args}{redirect_to},
            static_path    => Socialtext::Helpers::static_path(),
            skin_uri       => sub { Socialtext::Skin->skin_uri(shift) },
            st_version     => $Socialtext::VERSION,
            support_address => Socialtext::AppConfig->support_address,
            %$saved_args,
        };

        if ($uri eq 'choose_password.html') {
            my $saved_args = $self->session->saved_args;
            my $hash = $saved_args->{hash};
            return $self->_redirect('/nlw/login.html') unless $hash;

            my $user = $self->_find_user_for_email_confirmation_hash( $r, $hash );
            unless ($user) {
                return $self->_redirect('/nlw/login.html');
            }
            $vars->{email_address} = $user->email_address;
            $vars->{hash} = $hash;
        }

        # Include login_message_file content in vars sent to template
        # if login_message_file is set in AppConfig.
        if ( $uri eq 'login.html' ) {
            my $file = Socialtext::AppConfig->login_message_file();
            if ( $file and -r $file ) {
                # trap any errors and ignore them to the error log
                eval {
                    $vars->{login_message}
                        = Socialtext::File::get_contents_utf8($file);
                };
                warn $@ if $@;
            }
        }

        my @errors;
        if ($r->prev) {
            @errors = split /\n/, $r->prev->pnotes('error') || '';
        }
        if ($uri eq 'errors/500.html') {
            return $class->handle_error( $r, \@errors);
        }

        return $class->render_template($r, "authen/$uri", $vars);
    }

    warn "Unknown URI: $uri";
    return NOT_FOUND;
}

sub username_label {
    return username_is_email() ? loc('Email Address:') : loc('Username:');
}

sub username_is_email {
    return Socialtext::AppConfig->is_default('user_factories');
}

sub login {
    my ($self) = @_;
    my $r = $self->r;

    my $username = $self->{args}{username} || '';
    unless ($username) {
        $self->session->add_error(loc("You must provide a valid email address."));
        return $self->_redirect('/nlw/login.html');
    }

    my $user_check = ( username_is_email()
        ? Email::Valid->address($username)
        : ( $username =~ /\w/ )
    );

    unless ( $user_check ) {
        $self->session->add_error( loc('"[_1]" is not a valid email address. Please use your email address to log in.', $username) );
        $r->log_error ($username . ' is not a valid email address');
        return $self->_redirect('/nlw/login.html');
    }
    my $auth = Socialtext::Authen->new;
    my $user = Socialtext::User->new( username => $username );

    if ($user && !$user->email_address) {
        $self->session->add_error(loc("This username has no associated email address." ));
        $r->log_error ($username . ' has no associated email address');
        return $self->_redirect('/nlw/login.html');
    }

    if ($user and $user->requires_confirmation) {
        $r->log_error($username . ' requires confirmation');
        return $self->require_confirmation_redirect($user->email_address);
    }

    unless ($self->{args}{password}) {
        $self->session->add_error(loc("Wrong email address or password - please try again."));
        $r->log_error('Wrong email address or password for ' . $username);
        return $self->_redirect('/nlw/login.html');
    }

    my $check_password = $auth->check_password(
        username => ($username || ''),
        password => $self->{args}{password},
    );

    unless ($check_password) {
        $self->session->add_error(loc("Wrong email address or password - please try again."));
        $r->log_error('Wrong email address or password for ' . $username);
        return $self->_redirect('/nlw/login.html');
    }

    my $expire = $self->{args}{remember} ? '+12M' : '';
    Socialtext::Apache::User::set_login_cookie( $r, $user->user_id, $expire );

    $user->record_login;

    my $dest = $self->{args}{redirect_to};
    unless ($dest) {
        $dest = "/";
    }

    st_log->info( "LOGIN: " . $user->email_address . " destination: $dest" );

    $self->session->write;
    $self->redirect($dest);
}

sub logout {
    my $self     = shift;
    my $redirect = $self->{args}{redirect_to}
        || Socialtext::AppConfig->logout_redirect_uri();

    Socialtext::Apache::User::unset_login_cookie();
    $self->redirect($redirect);
}

sub forgot_password {
    my $self = shift;
    my $r = $self->r;

    my $username = $self->{args}{username} || '';
    my $user = Socialtext::User->new( username => $username );
    unless ( $user ) {
        $self->session->add_error(loc("[_1] is not registered as a user. Try a different email address?", $username));
        return $self->_redirect('/nlw/forgot_password.html');
    }

    $user->set_confirmation_info( is_password_change => 1 );
    $user->send_password_change_email();

    $self->session->add_message( 
        loc('An email with instructions on changing your password has been sent to [_1].', $user->username)
    );

    $self->session->save_args( username => $user->username() );

    $self->_redirect("/nlw/login.html");
}

sub register {
    my $self = shift;
    my $r = $self->r;

    my $email_address = $self->{args}{email_address};
    unless ( $email_address ) {
        $self->session->add_error(loc("Please enter an email address."));
        return $self->_redirect('/nlw/register.html');
    }

    my $user = Socialtext::User->new( email_address => $email_address );
    if ($user) {
        if ( $user->requires_confirmation() ) {
            return $self->require_confirmation_redirect($email_address);
        }
        elsif ( $user->has_valid_password() ) {
            $self->session->add_message(loc("A user with this email address ([_1]) already exists.", $email_address));
            $self->session->save_args( email_address => $email_address );

            return $self->_redirect("/nlw/register.html");
        }
    }

    my %args;
    for (qw(password password2 first_name last_name)) {
        $args{$_} = $self->{args}{$_} || '';
    }
    if ( $args{password} and $args{password} ne $args{password2} ) {
        $self->session->add_error(loc('The passwords you provided did not match.'));
    }

    eval {
        if ($user) {
            $user->update_store(
                password   => $args{password},
                first_name => $args{first_name},
                last_name  => $args{last_name},
            );
        }
        else {
            $user = Socialtext::User->create(
                username      => $email_address,
                email_address => $email_address,
                password      => $args{password},
                first_name    => $args{first_name},
                last_name     => $args{last_name},
            );
        }
    };
    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        # We don't show them "Username is required" since that field
        # is not on the form.
        $self->session->add_error($_) for grep { ! /Username.+required/i } $e->messages;
    }
    elsif ( $@ ) {
        die $@;
    }

    if ( $self->session->has_errors ) {
        my $redirect = delete $self->{args}{redirect_to};
        $self->session->save_args( %{ $self->{args} } );
        return $self->_redirect("/nlw/register.html");
    }

    $user->set_confirmation_info;
    $user->send_confirmation_email;

    $self->session->add_message(loc("An email confirming your registration has been sent to [_1].", $email_address));
    return $self->_redirect("/nlw/login.html");
}

sub confirm_email {
    my $self = shift;
    my $r = $self->r;

    my $hash = $self->{args}{hash};
    return $self->_redirect('/nlw/login.html') unless $hash;

    my $user = $self->_find_user_for_email_confirmation_hash( $r, $hash );
    unless ($user) {
        return $self->_redirect('/nlw/login.html');
    }

    if ( $user->confirmation_has_expired ) {
        $user->set_confirmation_info();

        if ( $user->confirmation_is_for_password_change() ) {
            $user->send_password_change_email();
        }
        else {
            $user->send_confirmation_email();
        }

        $self->session->add_error(loc("The confirmation URL you used has expired. A new one will be sent."));
        return $self->_redirect("/nlw/login.html");
    }

    if ( $user->confirmation_is_for_password_change or not $user->has_valid_password ) {
        $self->session->save_args(hash => $hash);
        return $self->_redirect( "/nlw/choose_password.html" );
    }

    $user->confirm_email_address();

    my $address = $user->email_address;
    $self->session->add_message(loc("Your email address, [_1], has been confirmed. Please login.", $address));
    $self->session->save_args( username => $user->username );
    return $self->_redirect("/nlw/login.html");
}

sub choose_password {
    my $self = shift;
    my $r = $self->r;

    my $hash = $self->{args}{hash};
    return $self->_redirect('/nlw/login.html') unless $hash;

        my $user = $self->_find_user_for_email_confirmation_hash( $r, $hash );
    unless ($user) {
        return $self->_redirect('/nlw/login.html');
    }

    my %args;
    $args{$_} = $self->{args}{$_} || '' for (qw(password password2));
    if ( $args{password} and $args{password} ne $args{password2} ) {
        $self->session->add_error(loc('The passwords you provided did not match.'));
    }
    eval { $user->update_store( password   => $args{password} ) };
    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        # We don't show them "Username is required" since that field
        # is not on the form.
        $self->session->add_error($_) for grep { ! /Username.+required/i } $e->messages;
    }

    if ( $self->session->has_errors ) {
        return $self->_redirect("/nlw/choose_password.html?hash=$hash");
    }

    $user->confirm_email_address;
    $self->session->add_message(loc('Your password has been set and you can now login.'));
    return $self->_redirect("/nlw/login.html");
}

sub resend_confirmation {
    my $self = shift;

    my $email_address = $self->{args}{email_address};
    unless ($email_address) {
        warn "No email address found to resend confirmation";
        return $self->_redirect('/nlw/login.html');
    }

    my $user = Socialtext::User->new( email_address => $email_address );
    unless ($user) {
        $self->session->add_error(loc("[_1] is not registered as a user. Try a different email address?", $email_address));
        return $self->_redirect('/nlw/login.html');
    }

    unless ($user->requires_confirmation) {
        $self->session->add_error(loc("The email address for [_1] has already been confirmed.", $email_address));
        return $self->_redirect('/nlw/login.html');
    }

    $user->set_confirmation_info;
    $user->send_confirmation_email;

    $self->session->add_error(loc('The confirmation email has been resent. Please follow the link in this email to activate your account.'));
    return $self->_redirect("/nlw/login.html");
}

sub require_confirmation_redirect {
    my $self          = shift;
    my $email_address = shift;

    $self->session->save_args( username => $email_address );
    $self->session->add_error( {
        type => 'requires_confirmation',
        args => {
           email_address => $email_address,
           redirect_to   => $self->{args}{redirect_to} || '',
       },
    } );

    return $self->_redirect("/nlw/login.html");
}

sub _redirect {
    my $self = shift;
    my $uri  = shift;
    my $redirect_to = $self->{args}{redirect_to};

    if ($redirect_to) {
        $uri .= ($uri =~ m/\?/ ? ';' : '?')
              . "redirect_to=" . uri_escape_utf8($redirect_to);
    }
    $self->redirect($uri);
}

sub _find_user_for_email_confirmation_hash {
    my $self = shift;
    my $r = shift;
    my $hash = shift;

    # now in order to deal with email clients that might have decoded %2B to '+' for us
    # we need to change spaces in the hash back to '+' signs.
    # see: https://rt.socialtext.net:444/Ticket/Display.html?id=26571
    $hash =~ s/ /+/g;

    my $user = Socialtext::User->new( email_confirmation_hash => $hash );
    unless ($user) {
        $self->session->add_error(loc("The given confirmation URL does not match any pending confirmations."));
        $self->session->add_error( "<br/>(" . $r->uri . "?" . $r->args . ")" );
        $r->log_error ("no confirmation hash for: [" . $r->uri . "?" . $r->args . "]" );
    }
    return $user;
}

1;

__END__
Actions:
    check: login
    check: logout
    check: forgot_password
    check: register
    resend_confirmation
    check: confirm_email
    choose_password
