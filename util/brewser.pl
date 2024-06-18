#!/usr/bin/perl -w
use strict;
use JSON::PP qw/decode_json/;
use Data::Dumper;
use Carp qw/confess/;

my $GR="\033[32m";
my $RED="\033[91m";
my $RST="\033[0m";
my $action = $ARGV[0] || 'help';


# Startup

if( !`which brew` ) {
  print "Homebrew must be installed!\n\n";
  help();
  exit(1);
}

my $cellar = `brew --cellar`;
chomp $cellar;


# CLI

if( $action eq 'list' ) {
  list();
}
elsif( $action eq 'installdeps' ) {
  install_deps();
}
elsif( $action eq 'checkdeps' ) {
  check_deps();
}
elsif( $action eq 'info' ) {
  info();
}
elsif( $action eq 'ensurehead' ) {
  ensure_head( $ARGV[1], $ARGV[2] || '' );
}
elsif( $action eq 'fixpc' ) {
  fix_pc( $ARGV[1], $ARGV[2] );
}
else {
  help();
}


# Actions

sub help {
  print "Brewser

Usage: ./brewser.pl [action] [arguments]

Actions:
  list                                  List packages and versions installed
  info [package name]                   Pretty print json install receipt of named package
  ensurehead [package name] [version]   Ensure HEAD version of a package is installed
                                          If a non-HEAD version is installed, it will be removed and the current HEAD installed.
                                          If a HEAD version is installed, even if old, nothing will happen.
                                          If a version is specified and the installed HEAD version is lower, it will be removed and the current HEAD installed.
  installdeps [ruby spec file]          Install dependencies for a specified brew package spec file
  checkdeps [ruby spec file]            Check missing dependencies for a specified brew package spec file
  fixpc [package name] [version]        Ensure both [pkg].pc and [pkg]-[ver].pc exist
";
}

sub list {
  my $pkgs = get_pkg_versions();
  for my $pkg ( keys %$pkgs ) {
    my $ver = $pkgs->{$pkg};
    print "$pkg,$ver\n";
  }
}

sub install_deps {
  my $rbspec = $ARGV[1];
  if( !$rbspec ) {
    help();
    exit 1;
  }
  my $spec = read_file( $rbspec );
  my $pkgs = get_pkg_versions();
  my @need;
  for my $line ( split( "\n", $spec ) ) {
    if( $line =~ m/^\s*depends_on "(.+?)"/ ) {
      my $dep = $1;
      if( my $ver = $pkgs->{ $dep } ) {
        print "$GR$dep\t\t=> version $ver$RST\n";
      }
      else {
        push( @need, $dep );
      }
    }
  }
  if( @need ) {
    my $allneed = join(' ', @need);
    print "Installing missing packages:\n";
    print "  ".join("\n  ", @need);
    print "\n";
    `brew install $allneed 1>&2`;
  }
}

sub check_deps {
  my $rbspec = $ARGV[1];
  if( !$rbspec ) {
    help();
    exit 1;
  }
  my $spec = read_file( $rbspec );
  my $pkgs = get_pkg_versions();
  my @need;
  for my $line ( split( "\n", $spec ) ) {
    if( $line =~ m/^\s*depends_on "(.+?)"/ ) {
      my $dep = $1;
      if( my $ver = $pkgs->{ $dep } ) {
        print "$GR$dep\t\t=> version $ver$RST\n";
      }
      else {
        push( @need, $dep );
      }
    }
  }
  if( @need ) {
    my $allneed = join(' ', @need);
    print "Missing brew package(s):\n";
    print "  ".join("\n  ", @need);
    print "\n";
  }
}

sub info {
  my $pkg = $ARGV[1];
  if( !$pkg ) {
    help();
    exit 1;
  }
  my ( $info, $ver ) = install_info( $pkg );
  if( !$info ) {
    print "$pkg is not installed\n";
    exit 1;
  }
  print JSON::PP->new->ascii->pretty->encode( $info );
  if( $ver =~ m/HEAD/ ) {
    my $headVersion = head_version( $pkg );
    print "HEAD version = $headVersion\n";
  }
}

sub ensure_head {
  my ( $pkg, $ver ) = @_;
  if( !$pkg ) {
    help();
    exit 1;
  }
  my ( $info ) = install_info( $pkg );
  my $spec = $info ? $info->{source}{spec} : '';
  if( !$spec || $spec ne 'head' ) {
    print "$pkg - Installing HEAD\n";
    `brew uninstall $pkg --ignore-dependencies` if( $spec );
    `brew install --HEAD $pkg`;
  }
  else {
    print "$GR$pkg - HEAD already installed$RST\n";
    if( $ver ) {
      my $installedVer = head_version( $pkg );
      my $greater = version_compare( $ver, $installedVer );
      if( $greater == 1 ) {
        print "Installed HEAD version is $installedVer; need $ver\n";
        `brew uninstall $pkg --ignore-dependencies`;
        `brew install --HEAD $pkg`;
      }
      elsif( $greater == 0 ) { print "$GR$pkg - installed HEAD is version ${installedVer} ( ==$ver )$RST\n"; }
      elsif( $greater == -1 ) { print "$GR$pkg - installed HEAD is version ${installedVer} ( >$ver )$RST\n"; }
    }                            
  }
}

# TODO Check if this fix_pc method is really necessary and if so attemp to remove sudo need
sub fix_pc {
  my ( $pkg, $ver ) = @_;
  if( !$pkg || !$ver ) {
    help();
    exit 1;
  }
  my $f1 = "/usr/local/lib/pkgconfig/$pkg.pc";
  my $f2 = "/usr/local/lib/pkgconfig/$pkg-$ver.pc";
  my $pc = pkg_pc_file( $pkg );
  if( !$pc ) {
    print "Could not fix pkgconfig for $pkg; could not locate installed pc file in Cellar\n";
    return
  }
  `sudo mkdir -p /usr/local/lib/pkgconfig`;
  if( ! -e $f2 ) {
    print "$f2 was missing; creating symlink to $pc\n";
    `sudo ln -s $pc $f2`;
  }
  if( ! -e $f1 ) {
    print "$f1 was missing; creating symlink to $pc\n";
    `sudo ln -s $pc $f1`;  
  }
}


# Internals

sub get_pkg_versions {
  my %pkgs;
  my @dirs = sort `find $cellar -name .brew -maxdepth 3 -type d`;
  for my $dir ( @dirs ) {
    $pkgs{ $1 } = $2 if( $dir =~ m|^$cellar/([^/]+)/([^/]+)/\.brew$| );
  }
  return \%pkgs;
}

sub read_file {
  my $file = shift;
  open( my $fh, "<$file" ) or confess("Could not open $file");
  my $data;
  { local $/ = undef; $data = <$fh>; }
  close( $fh );
  return $data;
}

sub install_info {
  my ( $pkg, $ver ) = @_;
  if( !$ver ) {
    my $path = `find $cellar/$pkg -maxdepth 1 2>/dev/null | tail -1`;
    chomp $path;
    return 0 if( !$path );
    my @parts = split( "/", $path );
    $ver = pop @parts;
  }
  my $receiptFile = "$cellar/$pkg/$ver/INSTALL_RECEIPT.json";
  return 0 if( ! -e $receiptFile );
  return decode_json( read_file( $receiptFile ) ), $ver;
}

sub files {
  my $path = shift;
  opendir( my $DIR, $path );
  my @files = readdir( $DIR );
  my @outfiles;
  for my $file ( @files ) {
    next if( $file =~ m/^\.+$/ );
    push( @outfiles, $file );
  }
  closedir( $DIR );
  return @outfiles;
}

sub pkg_pc_file {
  my ( $pkg ) = @_;
  my $path = `find $cellar/$pkg -maxdepth 1 2>/dev/null | tail -1`;
  chomp $path;
  return 0 if( !$path );
  my $pcPath = "$path/lib/pkgconfig";
  my @pcFiles = files( $pcPath );
  my $pc = "";
  for my $pcFile ( @pcFiles ) {
    if( $pcFile =~ m/$pkg(\-|\.)/ ) {
      $pc = "$pcPath/$pcFile";
      last;
    }
  }
  return 0 if( !$pc );
  return $pc;
}

sub head_version {
  my $pkg = shift;
  my $pc = pkg_pc_file( $pkg );
  return 0 if( !$pc );
  my $version = `cat $pc | grep Version | cut -d\\  -f2`;
  chomp $version;
  return $version;
}

sub version_compare {
  my ( $v1, $v2 ) = @_;
  my ( $semV1 ) = split(/\-/, $v1);
  my ( $semV2 ) = split(/\-/, $v2);
  my @p1 = split(/\./, $semV1);
  my @p2 = split(/\./, $semV2);
  my $p1Size = scalar(@p1);
  my $p2Size = scalar(@p2);
  my $max = $p1Size >= $p2Size ? $p1Size : $p2Size;
  for( my $i=0; $i<$max; $i++ ) {
    my $n1 = $p1[ $i ];
    my $n2 = $p2[ $i ];
    return -1 unless defined $n1;
    return 1 unless defined $n2;
    return -1 if( $n2 > $n1 );
    return 1 if( $n2 < $n1 );
  }
  return 0;
}