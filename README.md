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

The following keywords are available. In fact, any tokens that start with a listed keyword can be used (with some exceptions noted below).
## Stack Manipulation
* `push`: Pushes a value to the stack.<sup>1</sup>
* `dup`: Duplicates the top stack item.
* `copy`: Copies the *n*th stack item to the top of the stack.<sup>1</sup>
* `swap`: Swaps the top two stack items.
* `pop`: Removes the top stack item.
* `slide`: Removes the top *n* stack items, keeping the top item.<sup>1</sup>

## Arithmetic
* `add`: Addition
* `sub`: Subtraction
* `mul`: Multiplication
* `div`: Integer Division
* `mod`: Modulo

## Heap Access
* `stor`: Stores the value of the top stack item at the address given by the next stack item.
* `retr`: Retrieves the value at the address given by the top stack item and pushes it to the stack.

## Flow Control
* `label`: Declares a label.<sup>2</sup>
* `call`: Call a subroutine, effectively a jump to a label that also marks the current location for a later `ret`.<sup>2</sup>
* `jmp`: Unconditionally jump to a label.<sup>2</sup> Note: `jump` is accepted as a synonym.
* `jez`: Jump to a label if the top stack item is 0.<sup>2</sup> Note: `jz` is accepted as a synonym.
* `jlz`: Jump to a label if the top stack item is negative.<sup>2</sup>
* `ret`: Return to the location of the last `call` command. Note: Pattern matching for this command is actually `/^ret(?!r)/` so that `retrieve` unambiguously matches `retr`
* `end`: End the program. Note: `exit` is accepted as a synonym.

## I/O
* `ochar`: Output the character given by the value of the top stack item. Note: `putchar` is accepted as a synonym.
* `onum`: Output the value of the top stack item. Note: `putnum` is accepted as a synonym.
* `ichar`: Read a character and store it at the address given by the top stack item. Note: `getchar` is accepted as a synonym.
* `inum`: Read a number and store it at the address given by the top stack item. Note: `getnum` is accepted as a synonym.

## Notes
1. These commands expect the next token to be an integer which will then be encoded to the signed binary format described in the spec. If the next token doesn't look like an integer (i.e. doesn't match the regex /[+-]?\d+/) a 0 value will be inserted and a warning printed to STDERR.
2. These commands (currently) expect the next token to be a natural number (non-negative integer) which will then be encoded as a list of tabs and spaces as described in the spec. This is currently accomplished by converting the label to an unsigned binary format (i.e. the format used for numbers without a sign bit). As the spec allows for an empty label but the tokeniser treats consecutive whitespace as a single delimiter, if the next token doesn't look like a natural number (i.e. doesn't match the regex /\d+/) an empty label is inserted and parsing continues with no warning. If one of these commands is the last token in the file the generated Whitespace code will be invalid (see [#5](https://github.com/ephphatha/wsm2ws/issues/5)).
