#!/usr/bin/perl

# MIT License
#
# Copyright (c) 2023-2025 Struan Bartlett
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

use strict;
use warnings;
use JSON;
use Getopt::Long;

my $max_idle_time_io_event = 0.1; # Maximum idle time for "io" events
my $idle_time_simulated_io_event = $max_idle_time_io_event*2/3; # Idle time for simulated single-char "io" events
my $idle_time_io_cr_event = 1; # Idle time for "io" events with "\r" data
my $idle_time_first_i_event = 0; # Idle time for first "i" events (after sequence of consecutive "o" events)
my $max_idle_time_first_i_event = 1; # Maximum idle time for first "i" events (after sequence of consecutive "o" events)
my $max_idle_time_o_event = 3; # Maximum idle time for consecutive "o" events
my $debug = 0;

sub Usage {
    print "Usage: $0 [--max-idle-time-io-event <seconds>] [--idle-time-simulated-io-event <seconds>] [--idle-time-io-cr-event <seconds>] [--idle-time-first-i-event <seconds>] [--max-idle-time-first-i-event <seconds>] [--max-idle-time-o-event <seconds>] [--debug] <file_path>\n";
    exit;
}

# GetOpt::Long code for command line options for abovementioned variables
GetOptions(
    'max-idle-time-io-event=f' => \$max_idle_time_io_event,
    'idle-time-simulated-io-event=f' => \$idle_time_simulated_io_event,
    'idle-time-io-cr-event=f' => \$idle_time_io_cr_event,
    'idle-time-first-i-event=f' => \$idle_time_first_i_event,
    'max-idle-time-first-i-event=f' => \$max_idle_time_first_i_event,
    'max-idle-time-o-event=f' => \$max_idle_time_o_event,
    'debug' => \$debug,
    'h|help' => sub { Usage() },
);

# Replace with your actual file path
my $file_path = $ARGV[0];

# Open the file
my $fh;

if($file_path) {
    open $fh, '<', $file_path or die "Could not open file '$file_path' $!";
}
else {
    $fh = 'STDIN';
}

# Variable to keep track of the last event
my $last_event;
my $last_i_event;  # To track the last "i" event
my $last_o_event;  # To track the last "o" event
my $last_oi_event;  # To track the last "o" event following an "i" event
my $header_printed = 0;
my $time = 0;

# Process each line in the file
while (my $line = <$fh>) {
    chomp $line;
    
    # Decode the JSON line
    my $event = decode_json($line);

    # Check if it's a header
    if (ref($event) eq 'HASH') {
        if (exists $event->{'idle_time_limit'}) {
            # $max_idle_time_io_event = $event->{'idle_time_limit'};
            delete $event->{'idle_time_limit'};
        }
        print encode_json($event), "\n";
        $header_printed = 1;
        next;
    }

    # Ensure header is printed before processing events
    if (!$header_printed) {
        die "Error: Header not found in file";
    }

    $event->[3] = $event->[1];
    $event->[4] = $event->[0];

    if ($last_event) {
        $event->[5] = $event->[4] - $last_event->[4];
    }
    else {
        $event->[5] = 0;
    }
    
    if ($last_event) {

        # Apply idle time limit for "i" events following an "o" event that themselves followed an "i" event
        if ($event->[1] eq 'i') {

            if ($event->[2] eq "\r") {
                if ($event->[5] != $idle_time_io_cr_event) {
                    $event->[5] = $idle_time_io_cr_event;
                }
            }

            # If this is an "i" event, and the last "o" event was not an "oi" event (i.e. triggered by an "i" event)
            elsif ($last_event->[3] ne 'oi') {
                if( $idle_time_first_i_event ) {
                    $event->[5] = $idle_time_first_i_event;
                }
                elsif ($event->[5] > $max_idle_time_first_i_event) {
                    $event->[5] = $max_idle_time_first_i_event;
                }
            }

            # If this is not the first "i" event, and the last "o" event was an "oi" event (i.e. triggered by an "i" event)
            elsif ($last_event->[3] eq 'oi') {
                if ($event->[5] > $max_idle_time_io_event) {
                    $event->[5] = $max_idle_time_io_event;
                }
            }
        }

        # Match "o" events
        elsif ($event->[1] eq 'o') {

            # Match "o" events following an "o" event that was not preceded by an "i" event
            if ($last_event->[1] eq 'o') {
                if ($last_o_event && $last_o_event == $last_event) {
                    if ($event->[5] > $max_idle_time_o_event) {
                        $event->[5] = $max_idle_time_o_event;
                    }
                }
            }
            # Match "o" events following an "i" event, and label them as "oi" events
            elsif ($last_event->[1] eq 'i') {
                $event->[3] = "oi";

                # If this output consists of more than two non-ctrl characters, split it into multiple events
                # so that each event consists of a single non-ctrl character, spaced out by $idle_time_simulated_io_event
                if( $idle_time_simulated_io_event && $event->[2] =~ /^[^\x00-\x1F\x7F]{2}/ ) {
                    my $text = $event->[2];
                    while( $text =~ /^[^\x00-\x1F\x7F]/ ) {
                        my $char = substr($text, 0, 1, '');
                        print encode_json([ $time, 'o', $char ]), "\n";
                        $time += $idle_time_simulated_io_event;
                    }

                    $event->[2] = $text;
                }
            }
        }
    
        $time += $event->[5];
    }
    
    $event->[0] = $time;

    # Encode and output the modified event
    if($debug) {
        print encode_json($event), "\n";
    }
    else {
        print encode_json([ @$event[0,1,2] ]), "\n";            
    }
    
    # Update the last events
    $last_event = $event;
    $last_o_event = $event if $event->[1] eq 'o';
    $last_i_event = $event if $event->[1] eq 'i';
    
    # Save "o" event following an "i" event
    $last_oi_event = $event if defined $event->[3] && $event->[3] eq 'oi';
}

close $fh;
