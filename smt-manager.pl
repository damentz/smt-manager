#!/usr/bin/env perl

# smt-manager.pl - a script for managing logical cores
# Copyright (C) 2015  Steven Barrett
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

use warnings;
use strict;

use v5.20;

use Getopt::Long;
use Pod::Usage;

# This is the top folder where CPUs can be enumerated and more detail retrieved.
use constant SYS_CPU => '/sys/devices/system/cpu';
use constant DEBUG => '0';

sub get_cpu_indexes () {
    opendir( my $dh, SYS_CPU ) or die "Cannot open folder: " . SYS_CPU;
    my @cpu_indexes = map { s/cpu//r } grep { /^cpu[0-9]+/ } readdir($dh);
    closedir $dh;

    return \@cpu_indexes;
}

sub get_cpu_settings() {
    my $cpu_indexes = get_cpu_indexes();
    my $cpus = {};

    foreach my $cpu ( @$cpu_indexes ) {
        my $siblings_file = SYS_CPU . "/cpu$cpu/topology/thread_siblings_list";
        my $power_file    = SYS_CPU . "/cpu$cpu/online";
        my $cpu_settings = {
            'core_type' => 'unknown',
            'power'     => 'offline'
        };

        # Populate core topology, primary / logical
        if ( open( my $fh, '<', $siblings_file ) ) {

            my @siblings = split(/,|-/, <$fh>);
            close $fh;

            my $cpu_num = $cpu;
            $cpu_num =~ s/cpu(\d+)/$1/;

            if ( $cpu_num == $siblings[0] ) {
                $cpu_settings->{'core_type'} = 'primary';
            } else {
                $cpu_settings->{'core_type'} = 'logical';
            }

        } else {
            print "[ERROR] Could not open: $siblings_file\n" if DEBUG;
        }

        # Populate core status, online / offline
        if ( open my $fh, '<', $power_file ) {
            my $cpu_power = <$fh>;
            close $fh;

            chomp($cpu_power);

            $cpu_settings->{'power'} = 'online' if ($cpu_power == 1);
        } else {
            print "[ERROR] Could not open: $power_file, assuming online\n" if DEBUG;
            $cpu_settings->{'power'} = 'online';
        }

        $cpus->{$cpu} = $cpu_settings;

    }

    return $cpus;

}

sub set_logical_cpus($) {
    my $power_state = shift;
    my $cpus = get_cpu_settings();
    my $state_changed = 0;

    foreach my $cpu ( sort { $a <=> $b } keys %$cpus ) {
        if ( ($cpus->{$cpu}->{'core_type'} eq 'logical' ||
             $cpus->{$cpu}->{'core_type'} eq 'unknown') &&
             $cpus->{$cpu}->{'power'} ne $power_state ) {

            my $power_file = SYS_CPU . "/cpu$cpu/online";

            if ( open( my $fh, '>', $power_file ) ) {
                $state_changed = 1;

                print "Setting $cpu to $power_state ... ";

                print $fh '1' if $power_state eq 'online';
                print $fh '0' if $power_state eq 'offline';

                close $fh;
                print "done!\n";
            } else {
                print "[ERROR] failed to open file for writing: $power_file.  Are you root?\n"
            }
        }
    }

    if ( $state_changed ) {

        # Lets rebalance the interrupts after power state changes to guarantee
        # the system will remain stable.
        unless ( system( 'irqbalance --oneshot' ) == 0 ) {
            print STDERR "[ERROR] Failed to balance interrupts with 'irqbalance --oneshot', you may experience strange behavior.\n";
        }

        print "\n";
    }

    return $state_changed;
}

sub pretty_print_topology () {
    my $cpus = get_cpu_settings();

    print "CPU topology:\n";
    foreach my $cpu ( sort { $a <=> $b } keys %$cpus ) {
        print "$cpu: " . $cpus->{$cpu}->{'core_type'} . " | " . $cpus->{$cpu}->{'power'} . "\n";
    }

    print "\n";
}

### EXECUTE ###

my $help;
my $online;
my $offline;
my $manual;

GetOptions (
    'help'    => \$help,
    'online'  => \$online,
    'offline' => \$offline,
    'manual'  => \$manual
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-verbose => 2) if $manual;
if ( $online && $offline ) {
    pod2usage("Invalid option combination: you cannot offline and online at the same time.\n");
}

my $power_state;
$power_state = 'online'  if $online;
$power_state = 'offline' if $offline;


pretty_print_topology();

if ( defined $power_state && set_logical_cpus($power_state) ) {

    # If there was a change, print the new state.
    pretty_print_topology();
}

=pod

=head1 NAME

smt-manager.pl - View current status of CPU topology or set logical cores to
                offline or online.

=head1 SYNOPSIS

smt-manager.pl [options]

  --help        Prints this help.
  --online      Enables all logical CPU cores.
  --offline     Disables all logical CPU cores.
  --manual      Display man page of this script.

=head1 OPTIONS

=over 8

=item B<--help>

Prints standard help information and options that are available.

=item B<--online>

Attempts to enable all logical cores if they are already offline.  If they are
not offline, no changes will be made and no secondary topology print out will
occur.

=item B<--offline>

Performs the opposite action as --online.

=item B<--manual>

Displays help page as a man page and also displays description and summary.

=back

=head1 DESCRIPTION

This script provides the user details about whether each CPU is physical or
logical.  When provided an optional parameter, the logical CPUs can be enabled
or disabled.

Why would one want to disable logical cores?  Logical CPU cores with a high nice
value steal more CPU time than a physical core.  This is noticeable when
multitasking heavily, for instance, building a kernel with 8 cores as a very
nice (+20) task while running a greedy single threaded application.

By disabling the logical cores, the behavior and responsiveness of the system
will be more predictable, but throughput will drop as a whole for heavy multi-
threaded batch jobs.

=cut
