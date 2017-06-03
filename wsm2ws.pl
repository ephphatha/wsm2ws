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
  $ops{qr/^add/i} = { op => 'tsss', param => 'number_optional' };
  $ops{qr/^sub/i} = { op => 'tsst', param => 'number_optional' };
  $ops{qr/^mul/i} = { op => 'tssn', param => 'number_optional' };
  $ops{qr/^div/i} = { op => 'tsts', param => 'number_optional' };
  $ops{qr/^(mod|rem)/ni} = { op => 'tstt', param => 'number_optional' };

  # Heap Access
  $ops{qr/^stor/i} = { op => 'tts', param => 'number_optional' };
  $ops{qr/^retr/i} = { op => 'ttt', param => 'number_optional' };

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

        my ($op, $param) = @{$ops{$token->data}}{qw(op param)};

        unless ($op) {
          warn "Unrecognised token: ".$token->data;
          next;
        }

        my %instruction = (
          op => $op,
          token => $token->data
        );

        if ($param) {
          unless ($param eq 'self') {
            do {
              $token = $parser->nextToken;
            } while ($token->rule->name eq 'WHITESPACE');
          }

          given ($param) {
            when (/^number/) {
              my $isNumberToken = NUMBER_TOKEN_NAMES->{$token->rule->name};
              my $isOptional = $param =~ /optional$/;

              if ($isOptional && $isNumberToken) {
                warn "Shorthand instructions have not been implemented!";
                break;
              }

              if ($isNumberToken) {
                $instruction{op} .= whitespace_encode($token->data, signed => 1);
                $instruction{token} .= " ".$token->data;
              } else {
                unless ($isOptional) {
                  $instruction{op} .= whitespace_encode('0', signed => 1);
                  $instruction{token} .= " 0";
                }
              }

              unless ($isNumberToken) {
                warn "Expected a number but found: \"".$token->data."\"" unless $isOptional;
                push @instructions, \%instruction;
                redo TOKEN;
              }
            }
            when ('label') {
              my $isLabelToken = LABEL_TOKEN_NAMES->{$token->rule->name};

              if ($token->rule->name eq 'LABEL') {
                warn "Dynamic labels have not been implemented!";
                $instruction{op} .= whitespace_encode('0');
                $instruction{token} .= " NULL";
                break;
              }

              if ($isLabelToken) {
                $instruction{op} .= whitespace_encode($token->data);
                $instruction{token} .= " ".$token->data;
              } else {
                # Null label
                $instruction{op} .= whitespace_encode('0');
                $instruction{token} .= " NULL";
                push @instructions, \%instruction;
                redo TOKEN;
              }
            }
            when ('self') {
              # Special case for label: syntax
              if ($token->data =~ /(0[bx]?[\da-f]+|\d+):/i) {
                $instruction{op} .= whitespace_encode($1);
              } elsif ($token->data =~ /(.):/) {
                $instruction{op} .= whitespace_encode("'$1'");
              } else {
                warn "Unrecognised label format";
                $instruction{op} .= whitespace_encode('0');
              }
            }
          }
        }

        push @instructions, \%instruction;
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
