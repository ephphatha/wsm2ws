#! /usr/bin/env perl

use strict;
use warnings;

use feature qw(say);

use File::Basename;
use Text::ParseWords;
use Tie::RegexpHash;

main(@ARGV);

sub main {
  my %ops;
  
  tie %ops, 'Tie::RegexpHash';
  
  # Stack Manipulation
  $ops{qr/^push/i} = { op => 'ss', param => 'number' };
  $ops{qr/^dup/i} = { op => 'sns' };
  $ops{qr/^copy/i} = { op => 'sts', param => 'number' };
  $ops{qr/^swap/i} = { op => 'snt' };
  $ops{qr/^pop/i} = { op => 'snn' };
  $ops{qr/^slide/i} = { op => 'stn', param => 'number' };

  # Arithmetic
  $ops{qr/^add/i} = { op => 'tsss' };
  $ops{qr/^sub/i} = { op => 'tsst' };
  $ops{qr/^mul/i} = { op => 'tssn' };
  $ops{qr/^div/i} = { op => 'tsts' };
  $ops{qr/^mod/i} = { op => 'tstt' };

  # Heap Access
  $ops{qr/^stor/i} = { op => 'tts' };
  $ops{qr/^retr/i} = { op => 'ttt' };

  # Flow Control
  $ops{qr/^label/i} = { op => "nss", param => 'label' };
  $ops{qr/^call/i} = { op => "nst", param => 'label' };
  $ops{qr/^ju?mp/i} = { op => "nsn", param => 'label' };
  $ops{qr/^je?z/i} = { op => 'nts', param => 'label' };
  $ops{qr/^jlz/i} = { op => 'ntt', param => 'label' };
  $ops{qr/^ret(?!r)/i} = { op => 'ntn'};
  $ops{qr/^e(nd|xit)/ni} = { op => 'nnn'};

  # I/O
  $ops{qr/^(o|put)char/ni} = { op => 'tnss'};
  $ops{qr/^(o|put)num/ni} = { op => 'tnst'};
  $ops{qr/^(i|get)char/ni} = { op => 'tnts'};
  $ops{qr/^(i|get)num/ni} = { op => 'tntt'};

  my $filename = shift or die "Usage $0 <filename>";

  open(my $ifh, "<", $filename) or die "Cannot open $filename for reading: $!";

  my @instructions = ();

  my $need_param;

  while (<$ifh>) {
    s/;.*$//;

    foreach my $token (shellwords($_)) {
      if ($need_param) {
        if ($need_param eq 'number') {
          my $number = $token =~ /^[+-]?\d+$/ ? $token : '0';
          $instructions[-1]{op} .= encode_number($number);
          $instructions[-1]{token} .= " $number";
          unless ($number eq $token) {
            warn "Expected a number but found: $token";
            $need_param = undef;
            redo;
          }
        } elsif ($need_param eq 'label') {
          my $label = $token =~ /^\d+$/ ? $token : '';
          $instructions[-1]{op} .= encode_label($label);
          $instructions[-1]{token} .= " '$label'";
          unless (length($label)) {
            #handle null labels
            $need_param = undef;
            redo;
          }
        }
      
        $need_param = undef;
        next;
      }

      my $instruction = $ops{$token};

      unless ($instruction) {
        warn "Unrecognised token: $token";
        next;
      }

      (my $op, $need_param) = @$instruction{('op', 'param')};

      push @instructions, {
        op => $op,
        token => $token,
      };
    }
  }

  close($ifh);

  my $ws = join('', map { $_->{op} } @instructions);

  say "$ws";

  foreach my $instruction (@instructions) {
    say sprintf('%-5s', $instruction->{op})." ; $instruction->{token}";
  }

  my $outfilename = join('', (fileparse($filename, '.wsm'))[1,0], '.ws');

  open(my $ofh, ">", $outfilename) or die "Unable to open output file $outfilename for writing: $!";

  print $ofh $ws =~ tr/stn//cdr =~ tr/stn/ \t\n/r;

  close($ofh) or die "Error closing output file $outfilename: $!";

  say "See $outfilename for transpiled source";
}

sub encode_number {
  my $number = shift;
  # Special case handling for 0 to shorten output slightly
  return ($number < 0 ? 't' : 's').(sprintf('%b', abs($number)) =~ tr/01//cdr =~ s/^0$//r =~ tr/01/st/r).'n';
}

sub encode_label {
  my $label = shift;
  return (length($label) ? sprintf('%b', $label) =~ tr/01//cdr =~ tr/01/st/r : '' ).'n';
}
