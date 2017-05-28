#! /usr/bin/perl -w

use strict;

use feature qw(say);

use File::Basename;
use Scalar::Util qw(looks_like_number);
use Text::ParseWords;

main(@ARGV);

sub main {
  my %ops = (
    # Stack Manipulation
    push => {op => 'ss', param => 'number'},
    dup => 'sns',
    copy => {op => 'sts', param => 'number'},
    swap => 'snt',
    pop => 'snn',
    slide => {op => 'stn', param => 'number'},

    # Arithmetic
    add => 'tsss',
    sub => 'tsst',
    mul => 'tssn',
    div => 'tsts',
    mod => 'tstt',

    # Heap Access
    stor => 'tts',
    retr => 'ttt',

    # Flow Control
    label => {op => "nss", param => 'label'},
    call => {op => "nst", param => 'label'},
    jmp => {op => "nsn", param => 'label'},
    jez => {op => 'nts', param => 'label'},
    jlz => {op => 'ntt', param => 'label'},
    ret => 'ntn',
    end => 'nnn',

    # I/O
    ochar => 'tnss',
    onum => 'tnst',
    ichar => 'tnts',
    inum => 'tntt',
  );

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

      (my $op, $need_param) = ref($instruction) eq 'HASH' ? @$instruction{('op', 'param')} : ($instruction);

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
