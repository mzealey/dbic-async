package DBIx::Class::Storage::DBI::Async::Request;
use strict;
use warnings;
use AnyEvent;
use Promises ();
use Carp;
use DBIx::Class::Storage::DBI::Async::Deferred;

# Virtual functions requiring overload in 
sub _fh_to_watch { die "Virtual function" }
sub _query_completed { die "Virtual function" }
sub _get_execute_result { die "Virtual function" }

# Optional virtual function in order to allow query cancellation
#sub _cancel_query

# A wrapper around an sth which is like a DBI sth object but can be accessed
# via a promise to return async results
sub new {
    my ($class, $sth, $timeout) = @_;
    my $self = bless { sth => $sth } => $class;
    $self->{_timeout} = $timeout if $timeout;
    return $self;
}

sub _remove_watcher {
    # Kill the watcher
    undef shift->{io};
}

sub _setup_event {
    my ($self) = @_;

    if( !$self->{_deferred} ) {
        $self->{_deferred} = DBIx::Class::Storage::DBI::Async::Deferred->new;
        $self->{_deferred}->timeout( $self->{_timeout} ) if $self->{_timeout};
        $self->{_deferred}->set_cancel_fn(sub {
            $self->cancel(@_);
        });

        $self->{io} = AnyEvent->io( fh => $self->_fh_to_watch, cb => sub {
            return unless $self->_query_completed;

            $self->_remove_watcher;

            # Emulate the return value from execute() via promises
            if( my $rv = $self->_get_execute_result ) {
                $self->{_deferred}->resolve( $self->sth, $rv );
            } else {
                $self->{_deferred}->reject(
                    $self->sth->errstr || $self->sth->err || 'Unknown error: async result from execute() returned false, but error flags were not set...'
                );
            }
        });
    } else {
        carp 'Cannot call _setup_event twice';
    }
}

sub promise { shift->{_deferred}->promise }
sub sth { shift->{sth} }
sub dbh { shift->sth->{Database} }

sub execute {
    my $self = shift;
    $self->_setup_event;
    $self->sth->execute(@_);
    return $self->promise;
}

# Block waiting for response
sub _wait_for_response {
    my ($self) = @_;
    return if $self->promise->is_done;

    my $cv = AnyEvent->condvar;

    $self->promise->then(sub {
        $cv->send(shift);
    }, sub {
        warn "Got async error returned: " . shift;
        $cv->send(undef);
    });

    return $cv->recv;
}

sub cancel {
    my ($self, $from_timeout) = @_;

    return unless $self->can('_cancel_query');

    return unless $self->promise->is_in_progress;

    $self->_cancel_query;
    $self->_remove_watcher;
    $self->{_deferred}->reject( $from_timeout ? 'timeout' : 'cancelled' );
}

sub finish {
    my ($self) = @_;
    $self->cancel;
    $self->sth->finish;
}

# Emulating DBI blocking functions to enable seamless work with DBIx::Class normally
for my $sth_method (qw< fetch fetchall_arrayref fetchrow_array fetchrow_hashref >) {
    no strict 'refs';
    *{$sth_method} = sub {
        my $self = shift;
        $self->_wait_for_response;
        return $self->sth->$sth_method( @_ );
    }
}

# Proxy promise methods
for my $sth_method (qw< then done finally >) {
    no strict 'refs';
    *{$sth_method} = sub { shift->promise->$sth_method(@_) }
}

# Proxy all other DBI::st methods
our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    $self->sth->$method( @_ );
}

1;
