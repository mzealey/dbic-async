#!/usr/bin/perl
use v5.16;
use Promises backend => ['EV'], warn_on_unhandled_reject => [1];
use FindBin::libs;
use strictures;
use Try::Tiny;

use AnyEvent::Impl::EV;
use EV;
use Data::Printer;

use lib '../Songs/lib';
use Songs::AsyncSchema;

my $dbic = Songs::AsyncSchema->connect();

test_count();
test_cancel();

sub test_count {
    my $rs = $dbic->resultset('Songs');
    $rs->as_async->count->then(sub {
        my ($count) = @_;
        say "Count: $count";
    });
    $rs->search({}, { rows => 2 })->all->then(sub {
        p @_;
    });
    EV::run;
}

sub test_cancel {
    my @promises;
    my $rs = $dbic
            ->resultset('Songs')
            ->search({
            }, {
                columns => [
                    { foo => \'sum(length(songxml))' }
                ],
            });

    for my $id (1..3) {
        my $promise = $rs->as_async->all;
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
        ->resultset('Songs')
        ->search({}, { rows => 1 })
        ->all
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
