package DBIx::Class::ResultSetAsyncColumn;
use strict;
use warnings;
use base 'DBIx::Class::ResultSetColumn';

# TODO: Override most functions here to provide _p ones to wait on

sub next_p {
  my $self = shift;

  # using cursor so we don't inflate anything
  return $self->_resultset->cursor->next_p;
}

1
