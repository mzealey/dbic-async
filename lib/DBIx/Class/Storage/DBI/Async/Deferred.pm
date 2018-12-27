package DBIx::Class::Storage::DBI::Async::Deferred;
use strict;
use warnings;
use Carp;
use DBIx::Class::Storage::DBI::Async::Promise;

# TODO: This is pretty nasty and requires Promises to be instantiated with the
# given backend prior to this module being created
our @ISA = ( $Promises::Backend );

sub promise { DBIx::Class::Storage::DBI::Async::Promise->new(shift) }
sub set_cancel_fn {
    my ($self, $callback) = @_;
    $self->{_cancel_fn} = $callback
}

# Try to cancel the operation causing this promise
sub cancel {
    my ($self, $from_timeout) = @_;
    if( my $fn = $self->{_cancel_fn} ) {
        $fn->($from_timeout);
    }
}

# TODO: If we get the minor changes from https://github.com/mzealey/promises-perl/ accepted then the below becomes a whole lot easier. Something like:
#sub new {
#    my ($class, $parent) = @_;
#    my $self = $class->next::method;
#    $self->{_cancel_fn} = $parent->{_cancel_fn} if $parent;
#    return $self;
#}
#sub handle_timeout { shift->cancel(1) }

sub then {
    my $self = shift;
    my ( $callback, $error ) = $self->_callable_or_undef(@_);

    my $d = ( ref $self )->new;
    $d->set_cancel_fn( $self->{_cancel_fn} ) if $self->{_cancel_fn};
    push @{ $self->{'resolved'} } => $self->_wrap( $d, $callback, 'resolve' );
    push @{ $self->{'rejected'} } => $self->_wrap( $d, $error,    'reject' );

    $self->_notify unless $self->is_in_progress;
    $d->promise;
}

sub finally {
    my $self = shift;
    my ($callback) = $self->_callable_or_undef(@_);

    my $d = ( ref $self )->new;
    $d->set_cancel_fn( $self->{_cancel_fn} ) if $self->{_cancel_fn};

    if (defined $callback) {
        my ( @result, $method );
        my $finish_d = sub { $d->$method(@result); () };

        my $f = sub {
            ( $method, @result ) = @_;
            local $@;
            my ($p) = eval { $callback->(@result) };
            if ( $p && blessed $p && $p->can('then') ) {
                return $p->then( $finish_d, $finish_d );
            }
            $finish_d->();
            ();
        };

        push @{ $self->{'resolved'} } => sub { $f->( 'resolve', @_ ) };
        push @{ $self->{'rejected'} } => sub { $f->( 'reject',  @_ ) };

        $self->_notify unless $self->is_in_progress;
    }
    $d->promise;

}

sub timeout {
    my ( $self, $timeout ) = @_;

    unless( $self->can('_timeout') ) {
        carp "timeout mechanism not implemented for Promise backend ", ref $self;
        return $self->promise;
    }

    my $deferred = ref($self)->new;

    my $cancel = $deferred->_timeout($timeout, sub {
        return if $deferred->is_done;
        $self->cancel(1);
    } );

    $self->finally( $cancel )->then(
        sub { 'resolve', @_ },
        sub { 'reject',  @_ },
    )->then(sub {
        my( $action, @args ) = @_;
        $deferred->$action(@args) unless $deferred->is_done;
    });

    return $deferred->promise;
}

1
