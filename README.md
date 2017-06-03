# wsm2ws
Whitespace Assembly Language to Whitespace transpiler

## Usage
Run the program like `./wsm2ws.pl <filename>` with a filename as the first argument.

The Whitespace output will be written to a file in the same directory as the input file. If the filename ends in `.wsm` the output file will have the filename `<basename>.ws`, otherwise the filename will be `<filename>.ws`. For example `./wsm2ws.pl test.wsm` will create or overwrite the file `test.ws` in the current directory and `./wsm2ws.pl dir/test.pl` will create or overwrite the file `dir/test.pl.ws`.

The program will output a human readable version of the code to STDOUT followed by a tokenised version of the code then the name of the output file. While the tokenised code appends the keywords corresponding to each instruction as provided in the input file the output may differ slightlly when it comes to labels and numbers.

## Example
    $ ./wsm2ws.pl test.wsm
    nssnnsssnsssnssstnnstnnnn
    nssn  ; label ''
    nsssn ; label '0'
    sssn  ; push 0
    ssstn ; push 1
    nstn  ; call ''
    nnn   ; end
    See ./test.ws for transpiled source

## Notes
As is probably evident from the example this program does not attempt to validate or verify the whitespace code beyond ensuring correct syntax. It is up to the programmer to ensure the code will execute without errors.

Labels with leading spaces (other than the label `\s` - a single space) are currently unusable due to the integer representation expected of labels in wsm code. If I get around to making this an optimising transpiler I hope to process labels so the most frequently used labels get assigned the shortest sequences.

## Todo
See the list of [issues with the [enhancement] label](https://github.com/ephphatha/wsm2ws/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement).

## Bugs
Refer to the [issue tracker](https://github.com/ephphatha/wsm2ws/issues) (specifically [issues with the [bug] label](https://github.com/ephphatha/wsm2ws/issues?q=is%3Aissue+is%3Aopen+label%3Abug)).

# Whitespace Assemply Language Syntax
Keywords are generally derived from the first verb of the command description from the [Whitespace Tutorial](https://web.archive.org/web/20150618184706/http://compsoc.dur.ac.uk/whitespace/tutorial.php), with some abbreviations just to keep tokens to five characters or less.

## Comments
A semicolon (`;`) starts a comment, everything from that token to the end of the line will be ignored.

## Keywords
The following keywords are available. In fact, any tokens that start with a listed keyword can be used (with some exceptions noted below).

### Stack Manipulation
* `push`: Pushes a value to the stack.<sup>1</sup>
* `dup`: Duplicates the top stack item.
* `copy`: Copies the *n*th stack item to the top of the stack.<sup>1</sup>
* `swap`: Swaps the top two stack items.
* `pop`: Removes the top stack item.
* `slide`: Removes the top *n* stack items, keeping the top item.<sup>1</sup>

### Arithmetic
* `add`: Addition
* `sub`: Subtraction
* `mul`: Multiplication
* `div`: Integer Division
* `mod`: Modulo  
Synonyms: `rem`

### Heap Access
* `stor`: Stores the value of the top stack item at the address given by the next stack item.
* `retr`: Retrieves the value at the address given by the top stack item and pushes it to the stack.

### Flow Control
* `label`: Declares a label.<sup>2</sup>
* `call`: Call a subroutine, effectively a jump to a label that also marks the current location for a later `ret`.<sup>2</sup>
* `jmp`: Unconditionally jump to a label.<sup>2</sup>  
Synonyms: `jump`
* `jez`: Jump to a label if the top stack item is 0.<sup>2</sup>  
Synonyms: `jz`
* `jlz`: Jump to a label if the top stack item is negative.<sup>2</sup>  
Synonyms: `jn`
* `ret`: Return to the location of the last `call` command.  
Note: Pattern matching for this command is actually `/^ret(?!r)/` so that `retrieve` unambiguously matches `retr`
* `end`: End the program.  
Synonyms: `exit`

### I/O
* `ochar`: Output the character given by the value of the top stack item.  
Synonyms: `putchar`
* `onum`: Output the value of the top stack item.  
Synonyms: `putnum`
* `ichar`: Read a character and store it at the address given by the top stack item.  
Synonyms: `getchar`
* `inum`: Read a number and store it at the address given by the top stack item.  
Synonyms: `getnum`

### Notes
1. These commands expect the next token to be a number as described below. If the next token doesn't look like a number a 0 value will be inserted and a warning printed to STDERR.
2. These commands expect the next token to be a label as described below. As the spec allows for an empty label if the next token doesn't match the label rules an empty label is inserted and parsing continues with no warning.

## Numbers
Numbers can be written in any of the following formats:

* Integer (`[+-]?\d+`) - A sequence of digits.<sup>1</sup> <sup>2</sup>
* Binary (`[+-]?0b[01]+`) - The string `0b` followed by a sequence of `0` and `1` characters.<sup>1</sup> <sup>3</sup> <sup>4</sup>
* Octal (`[+-]?0[0-7]+`) - A `0` character followed by a sequence of digits between `0` and `7` (inclusive).<sup>1</sup>
* Hex (`[+-]?0x[\da-f]+`) - The string `0x` followed by a sequence of digits or the characters `a` to `f`.<sup>1</sup> <sup>4</sup>
* Character literal (`'\?.'`) - A single quoted character or escape sequence. Character literals will be converted to the corresponding ascii character code value.

### Notes
1. These formats can optionally be prefixed with a `+` or `-` character to specify the sign.
2. To shorten output slightly the integer 0 has special case handling so it is encoded as an empty sequence instead of a single space character. To avoid this behaviour use the binary/octal/hex format 
3. Leading `0` digits are significant when used with binary numbers.
4. These formats are case insensitive.

## Labels
While labels are not strictly numeric, for ease of representing labels in WSM syntax the following unsigned numerical formats are used:

* Integer (`\d+`) - A sequence of digits.<sup>1</sup>
* Binary (`0b[01]+`) - The string `0b` followed by a sequence of `0` and `1` characters.<sup>2</sup> <sup>3</sup>
* Octal (`0[0-7]`) - A `0` character followed by a sequence of digits between `0` and `7` (inclusive).
* Hex (`0x[\da-f]`) - The string `0x` followed by a sequence of digits or the characters `a` to `f`.<sup>3</sup>

### Notes
1. To shorten output slightly the integer 0 has special case handling so it is encoded as an empty sequence instead of a single space character. To avoid this behaviour use the binary/octal/hex format 
2. Leading `0` digits are significant when used with binary numbers.
3. These formats are case insensitive.