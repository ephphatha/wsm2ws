#! /usr/bin/env perl

use strict;
use warnings;

use feature qw(say);

use File::Basename;
use Parse::Token::Lite;
use String::Unescape qw(unescape);
use Tie::RegexpHash;

use experimental qw(switch);

use constant {
  NUMBER_TOKEN_NAMES => {map { $_ => 1 } qw(SIGNED_INTEGER INTEGER SIGNED_BINARY BINARY SIGNED_OCTAL OCTAL SIGNED_HEX HEX CHAR)},
  LABEL_TOKEN_NAMES => {map { $_ => 1 } qw(LABEL BINARY OCTAL HEX INTEGER)}
};

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
  $ops{qr/^add/i} = { op => 'tsss', param => 'number', optional => 1 };
  $ops{qr/^sub/i} = { op => 'tsst', param => 'number', optional => 1 };
  $ops{qr/^mul/i} = { op => 'tssn', param => 'number', optional => 1 };
  $ops{qr/^div/i} = { op => 'tsts', param => 'number', optional => 1 };
  $ops{qr/^(mod|rem)/ni} = { op => 'tstt', param => 'number', optional => 1 };

  # Heap Access
  # Note: The store command expects value to be at the top of the stack so we need
  #  to swap after pushing the address.
  $ops{qr/^stor/i} = { op => 'tts', param => 'number', optional => 1, swap => 1 };
  $ops{qr/^retr/i} = { op => 'ttt', param => 'number', optional => 1 };

  # Flow Control
  $ops{qr/^label/i} = { op => "nss", param => 'label' };
  $ops{qr/:$/i} = { op => "nss", param => 'self' };
  $ops{qr/^call/i} = { op => "nst", param => 'label' };
  $ops{qr/^ju?mp/i} = { op => "nsn", param => 'label' };
  $ops{qr/^je?z/i} = { op => 'nts', param => 'label' };
  $ops{qr/^j(n|lz)/ni} = { op => 'ntt', param => 'label' };
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

  my $parser = Parse::Token::Lite->new(rulemap => {
    MAIN => [
      { name => 'SIGNED_BINARY', re => qr/[+-]0b[01]+/ },
      { name => 'BINARY', re => qr/0b[01]+(?!:)/ },
      { name => 'SIGNED_OCTAL', re => qr/[+-]0[0-7]+/ },
      { name => 'OCTAL', re => qr/0[0-7]+(?!:)/ },
      { name => 'SIGNED_HEX', re => qr/[+-]0x[\da-f]+/i },
      { name => 'HEX', re => qr/0x[\da-f]+(?!:)/i },
      { name => 'SIGNED_INTEGER', re => qr/[+-]\d+/ },
      { name => 'INTEGER', re => qr/\d+(?!:)/ },
      { name => 'CHAR', re => qr/'\\?.'/ },
      { name => 'LABEL', re => qr/"[^"]*"/ },
      { name => 'COMMENT', re => qr/;.*/ },
      { name => 'KEYWORD', re => qr/\w+:?/ },
      { name => 'WHITESPACE', re => qr/\s+/ },
      { name => 'DEFAULT', re => qr/.*/ },
    ]
  });

  while (<$ifh>) {
    $parser->from($_);

    while (!$parser->eof) {
      my $token = $parser->nextToken;

      TOKEN: {
        next unless $token->rule->name eq 'KEYWORD';

        my $instruction = $ops{$token->data};

        unless ($instruction) {
          warn "Unrecognised token: ".$token->data;
          next;
        }

        $instruction = { %$instruction }; # clone so we can modify the opstring
        $instruction->{token} = $token->data;

        if ($instruction->{param}) {
          unless ($instruction->{param} eq 'self') {
            do {
              $token = $parser->nextToken;
            } while ($token->rule->name eq 'WHITESPACE');
          }

          given ($instruction->{param}) {
            when ('number') {
              my $isNumberToken = NUMBER_TOKEN_NAMES->{$token->rule->name};

              if ($isNumberToken) {
                if ($instruction->{optional}) {
                  my %pushOp = %{$ops{'push'}};
                  $pushOp{op} .= whitespace_encode($token->data, signed => 1);
                  $pushOp{token} = "push ".$token->data;

                  push @instructions, \%pushOp;

                  if ($instruction->{swap}) {
                    my %swapOp = %{$ops{'swap'}};
                    $swapOp{token} = "swap";

                    push @instructions, \%swapOp;
                  }
                } else {
                  $instruction->{op} .= whitespace_encode($token->data, signed => 1);
                  $instruction->{token} .= " ".$token->data;
                }
              } else {
                unless ($instruction->{optional}) {
                  $instruction->{op} .= whitespace_encode('0', signed => 1);
                  $instruction->{token} .= " 0";

                  warn "Expected a number but found: \"".$token->data."\"";
                }
                push @instructions, $instruction;
                redo TOKEN;
              }
            }
            when ('label') {
              my $isLabelToken = LABEL_TOKEN_NAMES->{$token->rule->name};

              if ($token->rule->name eq 'LABEL') {
                warn "Dynamic labels have not been implemented!";
                $instruction->{op} .= whitespace_encode('0');
                $instruction->{token} .= " NULL";
                break;
              }

              if ($isLabelToken) {
                $instruction->{op} .= whitespace_encode($token->data);
                $instruction->{token} .= " ".$token->data;
              } else {
                # Null label
                $instruction->{op} .= whitespace_encode('0');
                $instruction->{token} .= " NULL";
                push @instructions, $instruction;
                redo TOKEN;
              }
            }
            when ('self') {
              # Special case for label: syntax
              if ($token->data =~ /(0[bx]?[\da-f]+|\d+):/i) {
                $instruction->{op} .= whitespace_encode($1);
              } elsif ($token->data =~ /(.):/) {
                $instruction->{op} .= whitespace_encode("'$1'");
              } else {
                warn "Unrecognised label format";
                $instruction->{op} .= whitespace_encode('0');
              }
            }
          }
        }

        push @instructions, $instruction;
      }
    }
  }

  close($ifh);

  my $ws = join('', map { $_->{op} } @instructions);

  say "$ws";

  foreach my $instruction (@instructions) {
    say sprintf('%-5s', $instruction->{op})." ; $instruction->{token}";
  }

  my $outFilename = join('', (fileparse($filename, '.wsm'))[1,0], '.ws');

  open(my $ofh, ">", $outFilename) or die "Unable to open output file $outFilename for writing: $!";

  print $ofh $ws =~ tr/stn//cdr =~ tr/stn/ \t\n/r;

  close($ofh) or die "Error closing output file $outFilename: $!";

  say "See $outFilename for transpiled source";
}

sub whitespace_encode {
  my $token = shift;
  my %options = @_;

  my $sign = '';
  $sign = $token =~ /^[+-]/g =~ tr/+-/st/r || 's' if $options{signed};

  my $encodedString = (
    $token =~ /\G0b([01]+)$/i ? $1 : # binary
    $token =~ /\G(0(?:[0-7]+|x[\da-f]+))$/i ? sprintf('%b', oct($1)) : # octal/hex
    $token =~ /\G([1-9][\d]*)$/ ? sprintf('%b', $1) : # integer (non-zero)
    $token =~ /^'(\\.)'$/ ? sprintf('%b', ord(unescape($1))) : # escaped char
    $token =~ /^'(.)'$/ ? sprintf('%b', ord($1)) : # char
    '' # special case for 0 (or unrecognised token)
  ) =~ tr/01/st/r;

  return $sign.$encodedString.'n';
}
