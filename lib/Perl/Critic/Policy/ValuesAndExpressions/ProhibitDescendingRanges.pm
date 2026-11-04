package Perl::Critic::Policy::ValuesAndExpressions::ProhibitDescendingRanges;

# ABSTRACT: Do not write a range that counts down: Perl gives an empty list for it.

use strict;
use warnings FATAL => 'all';

use 5.014;

use re '/aa';

use Readonly;
use Scalar::Util qw{looks_like_number};

use Perl::Critic::Utils qw{
  :characters
  :severities
  is_method_call
  is_perl_builtin
  is_perl_builtin_with_list_context
  is_perl_builtin_with_zero_and_or_one_arguments
  precedence_of
};
use parent qw{Perl::Critic::Policy};

=head1 DESCRIPTION

In list context, Perl's range operator C<..> counts only up.  If the left end
is greater than the right end, Perl gives an empty list.  It does not count
down:

    my @countdown = 10 .. 1;              # violates: () and not (10, 9, ..., 1)

    foreach my $page ( $clamped .. 1 ) {   # violates: () when $clamped is 2 or more
        ...
    }

To count down, count up and reverse the list:

    foreach my $page ( reverse( 1 .. $clamped ) ) {
        ...
    }

=head2 What it reports

A range in list context, with C<..> or C<...>, where:

=over 4

=item * Both ends are number literals, and the left end is greater than the
right end, as in C<10 .. 1>.  Perl gives an empty list.  This includes negative
numbers (C<-1 .. -5>, C<5 .. -1>), hex, octal and binary numbers (C<0x10 .. 1>),
numbers with underscores (C<1_000 .. 999>), and numbers with an exponent
(C<1e1 .. 9>).  Perl truncates each end to an integer before it counts.  So the
policy compares the integers: C<2.5 .. 1.5> is reported, and C<1.5 .. 1.2>,
which gives C<(1)>, is not.

=item * Both ends are strings that Perl counts as numbers, as in C<'5' .. '1'>.
Perl counts a string range by numbers when both ends look like numbers and the
left end does not start with C<0>.  So C<'10' .. '09'> is C<10 .. 9>, and empty.

=item * Both ends are strings, and the left string is longer than the right
string, as in C<'aa' .. 'b'>.  Perl gives an empty list.

=item * Both ends are strings of the same length, and the left string sorts
after the right string, as in C<'z' .. 'a'>.  Perl does not count down here
either, and the list is not empty.  Perl counts up from the left string, and
stops before the first string that is longer.  So C<'z' .. 'a'> gives
C<('z')>, and C<'a3' .. 'a1'> gives the 257 strings from C<'a3'> to C<'z9'>.

=item * The left end is an expression and the right end is the number literal
0 or 1, as in C<$clamped .. 1>, C<$n .. 0> or C<$#list .. 0>.  The policy
cannot know the value of the expression.  But the range is never a countdown:
Perl gives an empty list whenever the expression is greater than the right end.
A range from an expression to 0 or 1 is almost always an attempt to count down.
A range to a larger number, such as C<$first .. 10>, almost always counts up.  So
the policy reports the first and not the second.  L</largest_end> sets the
largest right end that it reports.

=back

The message names the range and says what Perl gives for it.

C<...> is the same operator as C<..> in list context, and Perl gives the same
lists for it.  So the policy reports it in the same cases.

=head2 What it leaves alone

=over 4

=item * The flip-flop operator.  In scalar context, C<..> and C<...> are the
flip-flop operator, as in C<if ( /start/ .. /end/ )> or C<print if 3 .. 5>.  A
flip-flop does not make a list.  So the policy reports a range only where it
can see list context: the list of a C<for> loop or of a C<for> statement
modifier, an array or hash slice, an anonymous array or hash, the list of
C<map>, C<grep> or C<sort>, the block of C<map>, the arguments of a sub, of a
method or of a builtin that takes a list, C<return>, and the right side of an
assignment to an array, a hash or a list.  It does not report a range in the
condition of C<if>, C<unless>, C<while>, C<until>, a ternary or a statement
modifier, beside C<and>, C<or> or C<not>, in an assignment to a scalar, in
C<scalar()>, in the subscript of one element, or in a statement on its own.

=item * A range that counts up, or that has one element, as in C<1 .. 10>,
C<-5 .. -1>, C<'a' .. 'e'> and C<1 .. 1>.

=item * A string range where the left string is shorter than the right string,
as in C<'b' .. 'aa'> or C<'zz' .. 'aaa'>.  Perl counts up into the longer
strings, and it reaches the right end.

=item * A string range that counts up but does not do what it seems to do, as in
C<'A' .. 'z'>, which gives C<'A'> to C<'Z'>.  It does not count down, so it is
out of the scope of this policy.

=item * A range with an expression on the right, as in C<10 .. $n> or
C<10 .. 1 + $n>.  Its value is not known until the code runs.

=item * A range from an expression to a negative number, as in
C<@list[ -$n .. -1 ]>.  A negative number is an index from the end of an
array, so this range takes the last C<$n> elements, and it counts up.

=item * A version string, as in C<v1.2 .. 1>.

=back

=head1 CONFIGURATION

=head2 largest_end

The largest right end that the policy reports for a range whose left end is an
expression.  The default is 1, so C<$n .. 1> and C<$n .. 0> are reported, and
C<$n .. 2> is not.  A negative right end is never reported.  To report only
ranges with two literal ends, set it to -1:

    [ValuesAndExpressions::ProhibitDescendingRanges]
    largest_end = -1

=cut

=head2 METHODS

What L<Perl::Critic::Policy> asks of a policy, answered here rather than called
from anywhere.

=head3 supported_parameters

C<largest_end>.

=cut

Readonly::Scalar my $EXPL => q{Perl's .. counts only up, so a range whose left end is greater than its right end gives an empty list.  To count down, write reverse( LOW .. HIGH )};

# Operators that bind tighter than .. have a lower number here.
Readonly::Scalar my $RANGE => precedence_of(q{..});

Readonly::Hash my %RANGE_OPERATOR => map { $_ => 1 } qw{.. ...};

# Statement modifiers, and the words of the compound statements that take one.
Readonly::Hash my %SCALAR_MODIFIER => map { $_ => 1 } qw{if unless while until};
Readonly::Hash my %LIST_MODIFIER   => map { $_ => 1 } qw{for foreach};

# The operators that a list goes on past, to the left: a comma list and the
# branches of a ternary have the context of the whole expression.
Readonly::Hash my %LIST_SEPARATOR => map { $_ => 1 } ( $COMMA, $FATCOMMA, q{?}, $COLON );

# Words that an expression follows, and that are not a term of it.
Readonly::Hash my %NOT_A_TERM => map { $_ => 1 } qw{if unless while until for foreach my our local state return};

# The blocks whose value is a list, and the blocks after which a list follows.
Readonly::Hash my %LIST_BLOCK      => map { $_ => 1 } qw{map};
Readonly::Hash my %BLOCK_THEN_LIST => map { $_ => 1 } qw{map grep sort};

sub supported_parameters {
    return (
        {
            name           => 'largest_end',
            description    => 'The largest right end to report for a range whose left end is an expression',
            default_string => '1',
            behavior       => 'integer',
        },
    );
}

=head3 default_severity

High: the code runs, and a loop over the range does nothing.

=cut

sub default_severity { return $SEVERITY_HIGH }

=head3 default_themes

C<bugs>.

=cut

sub default_themes { return qw{bugs} }

=head3 applies_to

An operator, of which the policy looks only at C<..> and C<...>.

=cut

sub applies_to { return 'PPI::Token::Operator' }

=head3 violates

One violation for each range that counts down in list context.

=cut

sub violates {
    my ( $self, $elem ) = @_;
    return () unless $RANGE_OPERATOR{ $elem->content };

    my ( $left,  $before ) = _left_operand($elem);
    my ( $right, $after )  = _right_operand($elem);
    return () unless @$left && @$right;

    # The condition of a ternary is in boolean context: a flip-flop.
    return () if _is_question_mark($after);

    my $gives = $self->_what_perl_gives( $left, $right );
    return () unless defined $gives && _in_list_context( $elem, $before );

    my $range = join q{ }, _source(@$left), $elem->content, _source(@$right);
    return $self->violation( "$range $gives", $EXPL, $elem );
}

# What Perl gives for a range that counts down, as the end of the message, or
# undef for a range that does what it looks like.
sub _what_perl_gives {
    my ( $self, $left_operand, $right_operand ) = @_;

    my $left  = _literal(@$left_operand);
    my $right = _literal(@$right_operand);
    return unless defined $right;

    if ( !defined $left ) {
        return unless $right->{number};
        my $end = int $right->{value};
        return if $end < 0 || $end > $self->{_largest_end};
        my $start = _source(@$left_operand);
        return "gives an empty list when $start is more than $end";
    }

    my ( $from, $to ) = ( $left->{value}, $right->{value} );
    return unless defined $from && defined $to;
    if ( _counts_by_numbers( $left, $right ) ) {
        return unless looks_like_number($from) && looks_like_number($to);
        return int $from > int $to ? 'gives an empty list' : undef;
    }

    return 'gives an empty list' if length $from > length $to;
    return                       if length $from < length $to || $from le $to;

    # The same length, and $from sorts after $to.  Perl counts up from $from
    # by the magic increment, never meets $to, and stops before the first
    # string that is longer.  A string that is not letters then digits does
    # not increment, so Perl gives it alone.
    return "gives only ('$from')" unless $from =~ m/\A[[:alpha:]]*[[:digit:]]*\z/xs;
    my $last = join q{}, map { m/[[:digit:]]/xs ? q{9} : m/[[:upper:]]/xs ? q{Z} : q{z} } split m//xs, $from;
    return "gives only ('$from')" if $last eq $from;
    return "gives every string from '$from' up to '$last', and never reaches '$to'";
}

# Whether Perl counts this range by numbers, as pp_flop decides: a number at
# either end, or two strings that look like numbers where the left one does not
# start with 0.
sub _counts_by_numbers {
    my ( $left, $right ) = @_;
    return 1 if $left->{number} || $right->{number};
    return looks_like_number( $left->{value} ) && index( $left->{value}, q{0} ) != 0 && looks_like_number( $right->{value} );
}

# The value of an operand that is one literal, as { value => ..., number => 1 }
# for a number and { value => ... } for a string, or undef for anything else.
sub _literal {
    my (@operand) = @_;

    my $sign = 1;
    if ( @operand == 2 && $operand[0]->isa('PPI::Token::Operator') && $operand[0]->content eq q{-} ) {
        $sign = -1;
        shift @operand;
    }
    return if @operand != 1;
    my ($e) = @operand;

    if ( $e->isa('PPI::Token::Number') ) {

        # A version string is a literal, and not a number that the policy can compare.
        return {} if $e->isa('PPI::Token::Number::Version');
        my $value = $e->literal;
        return defined $value ? { value => $sign * $value, number => 1 } : undef;
    }

    # -'a' is the string '-a', which is not a number the policy can compare.
    return                          if $sign < 0;
    return { value => $e->literal } if $e->isa('PPI::Token::Quote::Single') || $e->isa('PPI::Token::Quote::Literal');
    if ( $e->isa('PPI::Token::Quote::Double') ) {
        my $string = $e->string;
        return if $e->interpolations || index( $string, q{\\} ) >= 0;
        return { value => $string };
    }
    return;
}

# The elements of the left operand of $elem, and the element before them.  An
# element binds to the operand if it is a term, or an operator that binds
# tighter than .., which is where Perl would end the operand.
sub _left_operand {
    my ($elem) = @_;
    my @operand;
    my $before = $elem->sprevious_sibling;
    while ( $before && _binds_on_the_left($before) ) {
        unshift @operand, $before;
        $before = $before->sprevious_sibling;
    }
    return ( \@operand, $before );
}

sub _right_operand {
    my ($elem) = @_;
    my @operand;
    my $after = $elem->snext_sibling;
    while ( $after && _binds_on_the_right($after) ) {
        push @operand, $after;
        $after = $after->snext_sibling;
    }
    return ( \@operand, $after );
}

sub _binds_tighter {
    my ($operator) = @_;
    my $precedence = precedence_of($operator);
    return defined $precedence && $precedence < $RANGE;
}

sub _binds_on_the_left {
    my ($e) = @_;
    return _binds_tighter($e) if $e->isa('PPI::Token::Operator');
    return 0                  if $e->isa('PPI::Token::Structure');

    if ( $e->isa('PPI::Token::Word') ) {
        return 0 if $NOT_A_TERM{ $e->content };
        return 1 if is_method_call($e) || is_perl_builtin_with_zero_and_or_one_arguments($e);
        my $after = $e->snext_sibling;
        return $after && $after->isa('PPI::Structure::List') ? 1 : 0;
    }

    # The block of map, grep or sort ends the operand: the list follows it.
    return !_follows_word( $e, \%BLOCK_THEN_LIST ) if $e->isa('PPI::Structure::Block');
    return 1;
}

sub _binds_on_the_right {
    my ($e) = @_;
    return _binds_tighter($e)                                                    if $e->isa('PPI::Token::Operator');
    return 0                                                                     if $e->isa('PPI::Token::Structure');
    return !( $SCALAR_MODIFIER{ $e->content } || $LIST_MODIFIER{ $e->content } ) if $e->isa('PPI::Token::Word');
    return 1;
}

sub _is_question_mark {
    my ($e) = @_;
    return $e && $e->isa('PPI::Token::Operator') && $e->content eq q{?};
}

# Whether the range at $elem, whose left operand starts after $before, is in
# list context.  It walks out to the left, past a comma list, a ternary and a
# bare parenthesised group, to the first thing that gives an expression a
# context.  Where it cannot tell, the answer is no, so that a flip-flop is never
# reported.
sub _in_list_context {
    my ( $elem, $before ) = @_;

    while (1) {
        if ( !$before ) {
            my $group = _bare_group_holding($elem);
            return _context_of_holder($elem) unless $group;

            my ( undef, $after ) = _right_operand($group);
            return 0 if _is_question_mark($after);
            return 1 if _is_list_slice($group);

            ( undef, $before ) = _left_operand($group);
            $elem = $group;
            next;
        }

        if ( $before->isa('PPI::Token::Operator') ) {
            my $operator = $before->content;
            return _is_list( $before->sprevious_sibling ) if $operator eq q{=};

            # A range operator here ends an earlier range in the same list.
            return 0 unless $LIST_SEPARATOR{$operator} || $RANGE_OPERATOR{$operator};
            $elem = $before;
            ( undef, $before ) = _left_operand($before);
            next;
        }

        return _gives_a_list($before) if $before->isa('PPI::Token::Word');
        return $before->isa('PPI::Structure::Block') ? 1 : 0;
    }
    return 0;
}

# Whether a word gives list context to the expression after it.
sub _gives_a_list {
    my ($word) = @_;
    my $name = $word->content;
    return 0 if $SCALAR_MODIFIER{$name};
    return 1 if $LIST_MODIFIER{$name} || $name eq 'return' || is_method_call($word);
    return 1 if is_perl_builtin_with_list_context($word);
    return is_perl_builtin($word) ? 0 : 1;
}

# The parenthesised group that the statement of $elem is the start of, if the
# group is an expression and not the list of a call or of a loop.
sub _bare_group_holding {
    my ($elem)    = @_;
    my $statement = $elem->parent;
    my $list      = $statement ? $statement->parent : undef;
    return unless $list && $list->isa('PPI::Structure::List');
    return if $list->parent->isa('PPI::Statement::Compound');

    my $before = $list->sprevious_sibling;
    return $list unless $before;
    return if $before->isa('PPI::Token::Word');
    return if $before->isa('PPI::Token::Operator') && $before->content eq q{->};
    return if $before->isa('PPI::Token::Symbol')   && index( $before->content, q{&} ) == 0;
    return $list;
}

# ( LIST )[ ... ], which PPI gives as a list and then a subscript, or a list
# and then an anonymous array.
sub _is_list_slice {
    my ($group) = @_;
    my $next = $group->snext_sibling;
    return 0 unless $next && ( $next->isa('PPI::Structure::Subscript') || $next->isa('PPI::Structure::Constructor') );
    return $next->start->content eq q{[} ? 1 : 0;
}

# The context that the structure around the statement of $elem gives it.
sub _context_of_holder {
    my ($elem)    = @_;
    my $statement = $elem->parent;
    my $holder    = $statement ? $statement->parent : undef;
    return 0 unless $holder;

    return 1                                      if $holder->isa('PPI::Structure::Constructor');
    return _is_slice($holder)                     if $holder->isa('PPI::Structure::Subscript');
    return _follows_word( $holder, \%LIST_BLOCK ) if $holder->isa('PPI::Structure::Block');
    return 0 unless $holder->isa('PPI::Structure::List');

    my $compound = $holder->parent;
    return $compound->type eq 'foreach' ? 1 : 0 if $compound->isa('PPI::Statement::Compound');

    # A call: _bare_group_holding has taken every list that is not one.
    my $before = $holder->sprevious_sibling;
    return $before->isa('PPI::Token::Word') ? _gives_a_list($before) : 1;
}

# Whether an element on the left of = takes a list: an array, a hash, a list
# or a slice.
sub _is_list {
    my ($e) = @_;
    return 0 unless $e;
    return 1 if $e->isa('PPI::Structure::List');
    return 1 if $e->isa('PPI::Token::Symbol')                                         && $e->content =~ m/\A[\@%]/xs;
    return 1 if ( $e->isa('PPI::Token::Symbol') || $e->isa('PPI::Structure::Block') ) && _after_list_cast($e);
    return $e->isa('PPI::Structure::Subscript') ? _is_slice($e) : 0;
}

# Whether a subscript takes a slice rather than one element: after an array or
# a hash, after @{...} or %{...}, or after ->@ or ->%.
sub _is_slice {
    my ($subscript) = @_;
    my $before = $subscript->sprevious_sibling;
    return 0 unless $before;
    return 1 if $before->isa('PPI::Token::Symbol') && $before->content =~ m/\A[\@%]/xs;
    return 1 if $before->isa('PPI::Token::Cast')   && $before->content =~ m/\A[\@%]\z/xs;
    return $before->isa('PPI::Structure::Block') && _after_list_cast($before) ? 1 : 0;
}

sub _after_list_cast {
    my ($e) = @_;
    my $cast = $e->sprevious_sibling;
    return $cast && $cast->isa('PPI::Token::Cast') && $cast->content =~ m/\A[\@%]\z/xs ? 1 : 0;
}

sub _follows_word {
    my ( $e, $words ) = @_;
    my $word = $e->sprevious_sibling;
    return $word && $word->isa('PPI::Token::Word') && $words->{ $word->content } ? 1 : 0;
}

# The source of a run of sibling elements, with the whitespace between them.
sub _source {
    my (@elements) = @_;
    my ( $first, $last ) = @elements[ 0, -1 ];
    my $source = q{};
    for ( my $e = $first; $e; $e = $e->next_sibling ) {
        $source .= $e->content;
        last if $e == $last;
    }
    return $source;
}

1;
