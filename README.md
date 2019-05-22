# smt-manager
Enable or disable hyperthreading cores, or display your current CPU topology.

## NAME
    smt-manager.pl - View current status of CPU topology or set logical cores
    to offline or online.

## SYNOPSIS
    smt-manager.pl [options]

      --help        Prints this help.
      --online      Enables all logical CPU cores.
      --offline     Disables all logical CPU cores.
      --manual      Display man page of this script.

## OPTIONS
    --help  Prints standard help information and options that are available.

    --online
            Attempts to enable all logical cores if they are already offline.
            If they are not offline, no changes will be made and no secondary
            topology print out will occur.

    --offline
            Performs the opposite action as --online.

    --manual
            Displays help page as a man page and also displays description and
            summary.

## DESCRIPTION
    This script provides the user details about whether each CPU is physical
    or logical. When provided an optional parameter, the logical CPUs can be
    enabled or disabled.

    Why would one want to disable logical cores? Logical CPU cores with a high
    nice value steal more CPU time than a physical core. This is noticeable
    when multitasking heavily, for instance, building a kernel with 8 cores as
    a very nice (+20) task while running a greedy single threaded application.

    By disabling the logical cores, the behavior and responsiveness of the
    system will be more predictable, but throughput will drop as a whole for
    heavy multi- threaded batch jobs.
