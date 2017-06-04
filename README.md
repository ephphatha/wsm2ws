# wsm2ws
Whitespace Assembly Language to Whitespace transpiler

## Usage
Run the program like `./wsm2ws.pl <filename>` with a filename as the first argument.

The Whitespace output will be written to a file in the same directory as the input file. If the filename ends in `.wsm` the output file will have the filename `<basename>.ws`, otherwise the filename will be `<filename>.ws`. For example `./wsm2ws.pl test.wsm` will create or overwrite the file `test.ws` in the current directory and `./wsm2ws.pl dir/test.pl` will create or overwrite the file `dir/test.pl.ws`.

The program will output a human readable version of the code to STDOUT followed by a tokenised version of the code then the name of the output file. While the tokenised code appends the keywords corresponding to each instruction as provided in the input file the output may differ slightlly when it comes to labels and numbers.

## Example
    $ cat examples/reverse.wsm
    push 0 ; initialise stack with 0. state: [0]
    input_loop:
    dup ichar ; read character from stdin (stored at address n). state: [n] [n:<char>]
    dup retr ; get character value from heap address n. state: [n, <char>]
    jez "output_loop"; null character read so assume end of input and start output loop. state: [n]
    add 1 ; increment n. state: [n+1]
    jmp "input_loop" ; continue input loop
    output_loop:
    sub 1 ; decrement n. state: [n-1]
    dup retr ; get character value from heap address n. state: [n, <char>]
    ochar ; write character to stdout. state: [n]
    jmp "output_loop" ; continue output loop

    $ ./wsm2ws.pl examples/reverse.wsm
    sssnnsstnsnstntssnstttntsnssstntsssnsntnnssnssstntsstsnsttttnssnsnn
    sssn  ; push 0
    nsssn ; input_loop:
    sns   ; dup
    tnts  ; ichar
    sns   ; dup
    ttt   ; retr
    ntsn  ; jez "output_loop"
    ssstn ; push 1
    tsss  ; add
    nsnsn ; jmp "input_loop"
    nssn  ; output_loop:
    ssstn ; push 1
    tsst  ; sub
    sns   ; dup
    ttt   ; retr
    tnss  ; ochar
    nsnn  ; jmp "output_loop"
    See examples/reverse.ws for transpiled source

## Notes
This program does not attempt to validate or verify the Whitespace code beyond ensuring correct syntax. It is up to the programmer to ensure the code will execute without errors. Problems with the example above include a missing end token, no way to leave the output loop, and there's no check to avoid executing retr with a negative heap address.

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
Synonyms: `swp`
* `pop`: Removes the top stack item.
* `slide`: Removes the top *n* stack items, keeping the top item.<sup>1</sup>

### Arithmetic
* `add`: Addition
* `sub`: Subtraction
* `mul`: Multiplication
* `div`: Integer Division
* `mod`: Modulo/Remainder  
Synonyms: `rem`

Arithmetic commands can be followed by a number to use as the RHS of the operation. A `push <number>` command will be inserted before the arithmetic command in the transpiled output. For example, sequences like `push 5 sub 3` will be transpiled to `push 5 push 3 sub`.

### Heap Access
* `stor`: Stores the value of the top stack item at the address given by the next stack item.
* `retr`: Retrieves the value at the address given by the top stack item and pushes it to the stack.

Heap access commands can be followed by a number to use as the heap address. For `stor` commands a push will be inserted into the transpiled output as described for arithmetic commands. `retr` commands are a little more complicated. As the spec uses the top stack value as the value to be stored and the second from the top as the address an additional `swap` command will be inserted between the `push` and the `retr` to maintain consistency with the `stor` syntax.

### Flow Control
* `label`: Declares a label.<sup>2</sup>
* `call`: Call a subroutine, effectively a jump to a label that also marks the current location for a later `ret`.<sup>2</sup>
* `jmp`: Unconditionally jump to a label.<sup>2</sup>  
Synonyms: `jump`, `goto`
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
Labels can be written in any of the following formats:

* Integer (`\d+`) - A sequence of 1 or more digits.<sup>1</sup> <sup>2</sup>
* Binary (`0b[01]+`) - The string `0b` followed by a sequence 1 or more of `0` and `1` characters.<sup>1</sup> <sup>3</sup> <sup>4</sup>
* Octal (`0[0-7]+`) - A `0` character followed by a sequence of 1 or more digits between `0` and `7` (inclusive).<sup>1</sup>
* Hex (`0x[\da-f]+`) - The string `0x` followed by a sequence of 1 or more digits or the characters `a` to `f`.<sup>1</sup> <sup>4</sup>
* Quoted string (`"[^"]*"`) - A sequence of 0 or more non-double-quote characters surrounded by double-quotes.<sup>5</sup>

### Notes
1. While labels are not numeric, for ease of representing labels in WSM syntax unsigned numerical formats are allowed. The binary representation of the number will be translated to a sequence of spaces and tabs to make a valid label.
2. To shorten output slightly the integer 0 has special case handling so it is encoded as an empty sequence instead of a single space character. To avoid this behaviour use the binary/octal/hex format 
3. Leading `0` digits are significant when used with binary numbers.
4. These formats are case insensitive.
5. The following rules apply when using strings for labels:
   * When a string is used for a label a sequence of space/tab characters (followed by a newline) will be generated for each reference in the Whitespace output such that the most frequently referenced strings receive the shortest unused sequence. Using the reverse program as an example `output_loop` gets the empty sequence because it has three references in the code and `input_loop` gets a length 1 sequence because it has two references. If there was another command using an implicit label (or the integer `0` as a label) the empty sequence would be unavailable, so `output_loop` would get a length 1 sequence (e.g. `sn`) and `input_loop` would get the next unique sequence of length 1 or greater (e.g. `tn`).
   * To support the short syntax for declaring a label when a `short_label:` token is encountered the text (excluding the `:`) will be treated as if it was a quoted string so that flow control statements can refer back to that location. For example `short_label: jump "short_label"` is equivalent to `label "short_label" jump "short_label"` and both commands will have the same generated label in the Whitespace output.