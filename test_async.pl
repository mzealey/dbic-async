#!/usr/bin/perl
use v5.16;
use Promises backend => ['EV'], warn_on_unhandled_reject => [1];
use FindBin::libs;
use strictures;
use Try::Tiny;

use AnyEvent::Impl::EV;
use EV;
use Data::Printer;

use Songs::AsyncSchema;

my $dbic = Songs::AsyncSchema->connect();

test_count();
test_cancel();

sub test_count {
    my $rs = $dbic->resultset('Song');
    $rs->as_async->count_p->then(sub {
        my ($count) = @_;
        say "Count: $count";
    });
    $rs->search({}, { rows => 2 })->as_async->all_p->then(sub {
        p @_;
    });
    EV::run;
}

sub test_cancel {
    my @promises;
    my $rs = $dbic
            ->resultset('Song')
            ->search({
            }, {
                columns => [
                    { foo => \'sum(length(songxml))' }
                ],
            });

    for my $id (1..3) {
        my $promise = $rs->as_async->all_p;
        push @promises, $promise;

        $promise
            ->then(sub {
                my (@rows) = @_;
                warn "$id done";
                #$_->cancel for @promises;
                for my $row (@rows) {
                    p $row;
                }
            }, sub {
                warn "Error $id: " . shift;
            });
    }

    my $promise = $dbic
        ->resultset('Song')
        ->search({}, { rows => 1 })
        ->as_async
        ->all_p
        ->then(sub {
            warn 'cancel';
            for( @promises) {
                try {
                    $_->cancel
                } catch {
                    say $_
                };
            }
        });

    warn 'running';
    EV::run;
}
