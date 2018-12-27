package DBIx::Class::ResultSetAsync;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use DBIx::Class::ResultSetAsyncColumn;

sub get_column {
  my ($self, $column) = @_;
  my $new = DBIx::Class::ResultSetAsyncColumn->new($self, $column);
  return $new;
}

sub all {
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

sub count {
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

# Clone the current resultset to use a new connection for the purposes of an async query.
sub as_async {
    my $self = shift;
    my $schema = $self->result_source->schema;
    my $new_schema = $schema->connect( @{$schema->storage->connect_info} );
    my $new_source = $new_schema->source($self->result_source->source_name);
    return $new_source->resultset_class->new($new_source, $self->{attrs});
}

1
