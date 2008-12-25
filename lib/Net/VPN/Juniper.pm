
package Net::VPN::Juniper;

use strict;
use warnings;
use Expect;

sub new {
    my ($class, %opts) = @_;

    my $self = bless {}, $class;

    $self->{ncsvc} = delete $opts{ncsvc} || 'ncsvc';

    return $self;
}

sub connected {
    my $self = shift;

    return defined $self->{exp} ? 1 : 0;
}

sub connect {
    my ($self, %opts) = @_;

    my $ncsvc = $self->{ncsvc};
    my $host = delete $opts{host} or die "No hostname supplied";
    my $username = delete $opts{username} or die "No username supplied";
    my $password = delete $opts{password} or die "No password supplied";
    my $realm = delete $opts{realm} or die "No realm supplied";
    my $cert = delete $opts{cert} or die "No cert supplied";

    my @args = (
        '-h' => $host,
        '-u' => $username,
        '-r' => $realm,
        '-f' => $cert,
    );

    # ncsvc hoses the resolver configuration, so let's back it up
    # so we can put it back when the VPN is closed down.
    die "I already seem to be running" if -f "/etc/resolv.conf.beforencsvc";
    rename('/etc/resolv.conf', '/etc/resolv.conf.beforencsvc') or die "Failed to move resolv.conf out of the way: $!";
    system('touch', '/etc/resolv.conf') && die "Failed to create new resolv.conf: $! (Your old resolv.conf is now called resolv.conf.beforencsvc)";

    my $exp = Expect->spawn($ncsvc, @args);
    $exp->debug(0);
    $exp->log_stdout(0);

    $exp->expect(undef, (
        [ 'Password: ' => sub {
            my $fh = shift;
            print $fh "$password\n";
            exp_continue;
        } ],
        [ 'Connecting to' => sub {
        } ],
    ));

    if ($exp->pid) {
        $self->{exp} = $exp;
        return 1;
    }
    else {
        return 0;
    }
}

sub disconnect {
    my $self = shift;

    if ($self->connected) {
        my $pid = $self->{exp}->pid;
        if ($pid) {
            kill 'INT', $pid;
            waitpid $pid, 0;
            delete $self->{exp};
        }

        if (-f '/etc/resolv.conf.beforencsvc') {
            unlink '/etc/resolv.conf';
            rename '/etc/resolv.conf.beforencsvc', '/etc/resolv.conf';
        }

    }

}

sub DESTROY {
    my $self = shift;

    $self->disconnect;
}


1;
