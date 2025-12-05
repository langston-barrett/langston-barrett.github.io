# Testing

## DSL-based integration tests

My favorite kind of test.

- [How to Test](https://matklad.github.io/2021/05/31/how-to-test.html)
- [How I Write Tests](https://blog.nelhage.com/2016/12/how-i-test/#design-a-testing-minilanguage-or-zoo)
- [Testing a Linker](https://davidlattimore.github.io/posts/2024/07/17/testing-a-linker.html)

Some examples:

- [Clang (Sema)](https://github.com/llvm/llvm-project/blob/main/clang/test/Sema/Float16.c)
- [GREASE](https://galoisinc.github.io/grease/dev/tests.html)
- [rust-analyzer](https://rust-analyzer.github.io/book/contributing/testing.html)
- [rustc](https://rustc-dev-guide.rust-lang.org/tests/compiletest.html)
- [Wild](https://github.com/llvm/llvm-project/blob/main/clang/test/Sema/Float16.c)

## Property-based testing

- Really stupid properties:
  - Is the output nontrivial (e.g. nonempty)?
  - Does the program not crash (i.e., fuzzing)?
  - Does the program satisfy its assertions/invariants/contracts?
- Property-preserving transformations: reversing a list doesn't change the max.
- Be inspired by math:
  - Test commutativity/intertwining of functions/methods
  - Test inverse relationships/functions
  - Test idempotency
  - Test structurally inductive properties
- Differential testing: equivalence with a simplified implementation or model

See:

- [Choosing properties for property-based testing](https://fsharpforfunandprofit.com/posts/property-based-testing-2/)
- [Finding property tests](https://www.hillelwayne.com/post/contract-examples/)

## Obscure types of testing

### Fault injection

> Fault injection is a software testing technique that involves inducing
> failures ("faults") in the functions called by a program. If the callee has
> failed to perform proper error checking and handling, these faults can result
> in unreliable application behavior or exploitable vulnerabilities.

<https://github.com/trailofbits/krf>

### Metamorphic testing

[Metamorphic testing] relates multiple executions or input/output pairs of the
same code. For example, doubling all the elements of a list also doubles the
mode. It is useful in combination with property testing.

[Metamorphic testing]: https://www.hillelwayne.com/post/metamorphic-testing/

### Mutation testing

Making automated changes to the code to see if the test suite will catch them.
"Testing tests" as it were.

- <https://github.com/agroce/universalmutator>
- <https://mutants.rs/>

## Particular types of system under test

### REST

#### Metamorphic Testing of RESTful Web APIs

<details>
<summary>Abstract</summary>

> Web Application Programming Interfaces (APIs) allow systems to interact
> with each other over the network. Modern Web APIs often adhere to the REST
> architectural style, being referred to as RESTful Web APIs. RESTful Web APIs
> are decomposed into multiple resources (e.g., a video in the YouTube API)
> that clients can manipulate through HTTP interactions. Testing Web APIs is
> critical but challenging due to the difficulty to assess the correctness of
> API responses, i.e., the oracle problem. Metamorphic testing alleviates the
> oracle problem by exploiting relations (so-called metamorphic relations) among
> multiple executions of the program under test. In this paper, we present a
> metamorphic testing approach for the detection of faults in RESTful Web APIs.
> We first propose six abstract relations that capture the shape of many of the
> metamorphic relations found in RESTful Web APIs, we call these Metamorphic
> Relation Output Patterns (MROPs). Each MROP can then be instantiated into one
> or more concrete metamorphic relations. The approach was evaluated using both
> automatically seeded and real faults in six subject Web APIs. Among other
> results, we identified 60 metamorphic relations (instances of the proposed
> MROPs) in the Web APIs of Spotify and YouTube. Each metamorphic relation
> was implemented using both random and manual test data, running over 4.7K
> automated tests. As a result, 11 issues were detected (3 in Spotify and 8 in
> YouTube), 10 of them confirmed by the API developers or reproduced by other
> users, supporting the effectiveness of the approach.

</details>

## Tools

- [crux-test-gen](https://github.com/GaloisInc/crucible/blob/master/crux-test-gen/example/vec1.txt)
- [FileCheck](https://llvm.org/docs/CommandGuide/FileCheck.html)
- [Oughta](https://github.com/GaloisInc/oughta)

## Further reading

- [How to Fuzz an ADT Implementation](https://blog.regehr.org/archives/896)
- [Just a Whole Bunch of Different Tests](https://www.hillelwayne.com/post/a-bunch-of-tests/)
- [rustc-dev-guide: Best practices for writing tests](https://github.com/rust-lang/rust/blob/3350c1eb3fd8fe1bee1ed4c76944d707bd256876/src/doc/rustc-dev-guide/src/tests/best-practices.md)
