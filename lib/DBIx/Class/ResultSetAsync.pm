package DBIx::Class::ResultSetAsync;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

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

1
