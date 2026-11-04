# NAME

Perl::Critic::Policy::ValuesAndExpressions::ProhibitDescendingRanges - Do not write a range that counts down: Perl gives an empty list for it.

# VERSION

version 0.001

# DESCRIPTION

In list context, Perl's range operator `..` counts only up.  If the left end
is greater than the right end, Perl gives an empty list.  It does not count
down:

```perl
my @countdown = 10 .. 1;              # violates: () and not (10, 9, ..., 1)

foreach my $page ( $clamped .. 1 ) {   # violates: () when $clamped is 2 or more
    ...
}
```

To count down, count up and reverse the list:

```perl
foreach my $page ( reverse( 1 .. $clamped ) ) {
    ...
}
```

## What it reports

A range in list context, with `..` or `...`, where:

- Both ends are number literals, and the left end is greater than the
right end, as in `10 .. 1`.  Perl gives an empty list.  This includes negative
numbers (`-1 .. -5`, `5 .. -1`), hex, octal and binary numbers (`0x10 .. 1`),
numbers with underscores (`1_000 .. 999`), and numbers with an exponent
(`1e1 .. 9`).  Perl truncates each end to an integer before it counts.  So the
policy compares the integers: `2.5 .. 1.5` is reported, and `1.5 .. 1.2`,
which gives `(1)`, is not.
- Both ends are strings that Perl counts as numbers, as in `'5' .. '1'`.
Perl counts a string range by numbers when both ends look like numbers and the
left end does not start with `0`.  So `'10' .. '09'` is `10 .. 9`, and empty.
- Both ends are strings, and the left string is longer than the right
string, as in `'aa' .. 'b'`.  Perl gives an empty list.
- Both ends are strings of the same length, and the left string sorts
after the right string, as in `'z' .. 'a'`.  Perl does not count down here
either, and the list is not empty.  Perl counts up from the left string, and
stops before the first string that is longer.  So `'z' .. 'a'` gives
`('z')`, and `'a3' .. 'a1'` gives the 257 strings from `'a3'` to `'z9'`.
- The left end is an expression and the right end is the number literal
0 or 1, as in `$clamped .. 1`, `$n .. 0` or `$#list .. 0`.  The policy
cannot know the value of the expression.  But the range is never a countdown:
Perl gives an empty list whenever the expression is greater than the right end.
A range from an expression to 0 or 1 is almost always an attempt to count down.
A range to a larger number, such as `$first .. 10`, almost always counts up.  So
the policy reports the first and not the second.  ["largest\_end"](#largest_end) sets the
largest right end that it reports.

The message names the range and says what Perl gives for it.

`...` is the same operator as `..` in list context, and Perl gives the same
lists for it.  So the policy reports it in the same cases.

## What it leaves alone

- The flip-flop operator.  In scalar context, `..` and `...` are the
flip-flop operator, as in `if ( /start/ .. /end/ )` or `print if 3 .. 5`.  A
flip-flop does not make a list.  So the policy reports a range only where it
can see list context: the list of a `for` loop or of a `for` statement
modifier, an array or hash slice, an anonymous array or hash, the list of
`map`, `grep` or `sort`, the block of `map`, the arguments of a sub, of a
method or of a builtin that takes a list, `return`, and the right side of an
assignment to an array, a hash or a list.  It does not report a range in the
condition of `if`, `unless`, `while`, `until`, a ternary or a statement
modifier, beside `and`, `or` or `not`, in an assignment to a scalar, in
`scalar()`, in the subscript of one element, or in a statement on its own.
- A range that counts up, or that has one element, as in `1 .. 10`,
`-5 .. -1`, `'a' .. 'e'` and `1 .. 1`.
- A string range where the left string is shorter than the right string,
as in `'b' .. 'aa'` or `'zz' .. 'aaa'`.  Perl counts up into the longer
strings, and it reaches the right end.
- A string range that counts up but does not do what it seems to do, as in
`'A' .. 'z'`, which gives `'A'` to `'Z'`.  It does not count down, so it is
out of the scope of this policy.
- A range with an expression on the right, as in `10 .. $n` or
`10 .. 1 + $n`.  Its value is not known until the code runs.
- A range from an expression to a negative number, as in
`@list[ -$n .. -1 ]`.  A negative number is an index from the end of an
array, so this range takes the last `$n` elements, and it counts up.
- A version string, as in `v1.2 .. 1`.

# CONFIGURATION

## largest\_end

The largest right end that the policy reports for a range whose left end is an
expression.  The default is 1, so `$n .. 1` and `$n .. 0` are reported, and
`$n .. 2` is not.  A negative right end is never reported.  To report only
ranges with two literal ends, set it to -1:

```
[ValuesAndExpressions::ProhibitDescendingRanges]
largest_end = -1
```

## METHODS

What [Perl::Critic::Policy](https://metacpan.org/pod/Perl%3A%3ACritic%3A%3APolicy) asks of a policy, answered here rather than called
from anywhere.

### supported\_parameters

`largest_end`.

### default\_severity

High: the code runs, and a loop over the range does nothing.

### default\_themes

`bugs`.

### applies\_to

An operator, of which the policy looks only at `..` and `...`.

### violates

One violation for each range that counts down in list context.

# BUGS

Please report any bugs or feature requests on the bugtracker website
[https://github.com/teodesian/perl-critic-policy-prohibitdescendingranges/issues](https://github.com/teodesian/perl-critic-policy-prohibitdescendingranges/issues)

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

# AUTHORS

Current Maintainers:

- George S. Baugh <george@troglodyne.net>

# CONTRIBUTOR

troglodyne-robot <352534226+troglodyne-robot@users.noreply.github.com>

# COPYRIGHT AND LICENSE

Copyright (c) 2026 Troglodyne LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
