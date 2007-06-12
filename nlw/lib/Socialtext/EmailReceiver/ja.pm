# @COPYRIGHT@
package Socialtext::EmailReceiver::ja;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Socialtext::EmailReceiver::Base';
use Readonly;
use Socialtext::Validate
    qw( validate SCALAR_TYPE HANDLE_TYPE WORKSPACE_TYPE );

require bytes;
use DateTime;
use Email::Address;
use Email::MIME;
use Email::MIME::ContentType ();
use Email::MIME::Modifier; # provides walk_parts()
use Fcntl qw( SEEK_SET );
use Filesys::DfPortable ();
use HTML::TreeBuilder ();
use HTML::WikiConverter ();
use Socialtext::Authz;
use Socialtext::CategoryPlugin;
use Socialtext::Exceptions qw( auth_error system_error );
use Socialtext::Log qw( st_log );
use Socialtext::Permission qw( ST_EMAIL_IN_PERM );
use Socialtext::User ();
use Text::Flowed ();

sub new {
    my $pkg = shift;
    bless {}, $pkg;
}

sub _new {
    my $class     = shift;
    my $email     = shift;
    my $workspace = shift;

    return bless {
        email          => $email,
        workspace      => $workspace,
        body           => '',
        attachments    => [],
        categories     => [ 'Email' ],
        body_placement => $workspace->incoming_email_placement(),
    }, $class;
}


{
    Readonly my $spec => {
        handle    => HANDLE_TYPE,
        workspace => WORKSPACE_TYPE,
    };

    sub receive_handle {
        my $class = shift;
        my %p = validate( @_, $spec );

        my $h = $p{handle};
        my $email = Email::MIME->new( do { local $/; <$h>} );

        my $self = $class->_new( $email, $p{workspace} );

        $self->_receive();

        return;
    }
}

{
    Readonly my $spec => {
        string    => SCALAR_TYPE,
        workspace => WORKSPACE_TYPE,
    };

    sub receive_string {
        my $class = shift;
        my %p = validate( @_, $spec );

        my $email = Email::MIME->new( $p{string}, $p{workspace}  );

        my $self = $class->_new( $email, $p{workspace} );

        $self->_receive();

        return;
    }
}


1;
