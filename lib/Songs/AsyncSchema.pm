use utf8;
package Songs::AsyncSchema;

use strict;
use warnings;

use lib '../Songs/lib';
use Songs::Schema;
use base 'DBIx::Class::Schema';

# If it was not for the default_resultset_class needing to be set then we could do this as a separate connect_async function in Songs::Schema
__PACKAGE__->load_namespaces(
    result_namespace => '+Songs::Schema::Result',
    default_resultset_class => '+DBIx::Class::ResultSetWithAsync'
);

sub connect {
    my $self = shift;
    $self->SUPER::connect( @{Songs::Schema->conn_info} );
}

1;

