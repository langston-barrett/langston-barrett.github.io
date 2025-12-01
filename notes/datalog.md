# Datalog

## Overview

Datalog is a declarative logic programming language. A Datalog program is a collection of rules specifying how to deduce relations among elements of some domain from some input relations. For example, the following program specifies the relation `reachable` in terms of another relation `edge` (which could be an input to the program):

``` fundamental
reachable(X, Y) :- edge(X, Y).
reachable(X, Y) :- edge(X, Z), reachable(Z, Y).
```

Operationally, a Datalog interpreter might take a CSV file or database table which specifies the `edge` relation, perform the computation/deductions specified by the program, and output the `reachable` relation as another CSV file or database table.

Datalog is related to Prolog, which is sort of a less declarative and also Turing-complete version of Datalog.

## Join order

The join order is the order in which the many tables involved in a rule are traversed. For example, ignoring the presence of indices, the rule

```souffle
r(a, c) :- p(a, b), q(b, c)
```

will have to traverse the tables containing relations `p` and `q` to compute `r`.

The join order of a rule can have a sizable impact on its performance. For Soufflé, the join order is determined (mostly!) by the syntactic order of the clauses. Consider the following example in Soufflé:

```souffle
r(a, c) :- p(a, b), s(b), q(b, c)
```

If `p` has many tuples, but `q` has less and `s` has even fewer, then a better ordering would be

```souffle
r(a, c) :- s(b), q(b, c), p(a, b).
```

because (again, ignoring indices) the above rule would essentially be evaluated like the following nested for-loop:

```python
for b in s:
    for (b0, c) in q:
        if b == b0:
            for (a, b1) in p:
                if b == b1:
                    r.insert(a, c)
```

Essentially, you want the *most selective* conditions to appear first, so that the innermost loops are executed the fewest number of times.

To get a feel for join order, it can be helpful to examine Soufflé's imperative RAM IR.
