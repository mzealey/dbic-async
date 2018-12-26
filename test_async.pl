#!/usr/bin/perl
use Promises backend => ['EV'], warn_on_unhandled_reject => [1];
use FindBin::libs;
use strictures;
use Try::Tiny;

use AnyEvent::Impl::EV;
use EV;
use Data::Printer;

use lib '../Songs/lib';
use Songs::AsyncSchema;

sub dbic { Songs::AsyncSchema->connect };

test_serial();
test_cancel();

sub test_serial {
    #my @foo = dbic()->resultset('Songs')->count;
    #warn @foo;
    my @bar = dbic()->resultset('Songs')->search({}, { rows => 2 })->all->then(sub {
        p @_;
    });
    EV::run;
}

sub test_cancel {
    my @cursors;
    for my $id (1..3) {
        my $cursor = dbic()
            ->resultset('Songs')
            ->search({
            }, {
                columns => [
                    { foo => \'sum(length(songxml))' }
                ],
            })
            ->all
            ;
        push @cursors, $cursor;

        $cursor
            ->then(sub {
                my (@rows) = @_;
                warn "$id done";
                #$_->cancel for @cursors;
                for my $row (@rows) {
                    p $row;
                }
            }, sub {
                warn "Error $id: " . shift;
            });
    }

    my $cursor = dbic()
        ->resultset('Songs')
        ->search({}, { rows => 1 })
        ->all
        ->then(sub {
            warn 'cancel';
            for( @cursors) {
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
