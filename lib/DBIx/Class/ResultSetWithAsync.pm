package DBIx::Class::ResultSetWithAsync;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use DBIx::Class::ResultSetAsync;

# Clone the current resultset to use a new connection for the purposes of an async query.
sub as_async {
    my $self = shift;
    my $schema = $self->result_source->schema;
    my $new_schema = $schema->clone;

    # TODO: how to generalize to any driver with async ability? Just tack ::Async on the end of the current driver name and die if it doesn't exist?
    $new_schema->storage_type('::DBI::Pg::Async');

    $new_schema->connection( @{$schema->storage->connect_info} );
    my $new_source = $new_schema->source($self->result_source->source_name);

    # TODO: How to handle custom resultsets?
    $new_source->resultset_class( 'DBIx::Class::ResultSetAsync' );
    return $new_source->resultset_class->new($new_source, $self->{attrs});
}

1
