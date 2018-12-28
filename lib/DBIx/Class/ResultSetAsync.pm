package DBIx::Class::ResultSetAsync;
use strict;
use warnings;
use base 'DBIx::Class::ResultSetWithAsync';
use DBIx::Class::ResultSetAsyncColumn;
use Carp;

sub get_column {
  my ($self, $column) = @_;
  my $new = DBIx::Class::ResultSetAsyncColumn->new($self, $column);
  return $new;
}

# Ensure people are using the async calls in this class to avoid getting weird errors like "cannot call ->then() on 2"
for my $method (qw< all count update delete >) {
    no strict 'refs';
    *{$method} = sub {
        carp "Cannot use non-async method on async resultset - use ${method}_p instead";
    };
}

# This just creates a ::Row item so no need to async it
sub create { carp "Cannot create in an async result set - doesnt make any sense"; }

# ResultSet update/delete are identical; they just return a promise instead of a row count
sub update_p { shift->SUPER::update( @_ ) }
sub delete_p { shift->SUPER::delete( @_ ) }

sub all_p {
  my $self = shift;
  if(@_) {
    $self->throw_exception("all() doesn't take any arguments, you probably wanted ->search(...)->all()");
  }

  delete @{$self}{qw/_stashed_rows _stashed_results/};

  if (my $c = $self->get_cache) {
    return @$c;
  }

  $self->cursor->reset;
  return $self->cursor->all_p->then(sub {
      my $objs = $self->_construct_results('fetch_all') || [];

      $self->set_cache($objs) if $self->{attrs}{cache};

      return @$objs;
  });
}

sub count_p {
  my $self = shift;
  return $self->search(@_)->count if @_ and defined $_[0];
  #return scalar @{ $self->get_cache } if $self->get_cache;

  my $attrs = { %{ $self->_resolved_attrs } };

  # this is a little optimization - it is faster to do the limit
  # adjustments in software, instead of a subquery
  my ($rows, $offset) = delete @{$attrs}{qw/rows offset/};

  my $crs;
  if ($self->_has_resolved_attr (qw/collapse group_by/)) {
    $crs = $self->_count_subq_rs ($attrs);
  }
  else {
    $crs = $self->_count_rs ($attrs);
  }
  return $crs->next_p->then(sub {
    my $count = $crs->next;

    $count -= $offset if $offset;
    $count = $rows if $rows and $rows < $count;
    $count = 0 if ($count < 0);

    return $count;
  });
}

1
