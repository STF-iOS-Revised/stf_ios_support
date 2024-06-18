#!/usr/bin/perl -w
use strict;

my $brew_check = `./util/brewser.pl checkdeps stf_ios_support.rb`;
if( $brew_check =~ m/Missing/ ) {
  print STDERR $brew_check, "\nRun init.sh to correct\n";
  exit 1 ;
}
if( $brew_check =~ m/Brew must be installed/ ) {
  print STDERR "Homebrew must be installed", "\nRun init.sh to correct\n";
  exit 1 ;
}

unless (-e "config.json") {
  print STDERR "The file config.json file does not exist.", "\nRun 'make config.json' to create it and then manually edit it\n";
  exit 1 ;
}

`./check-versions.pl`;
