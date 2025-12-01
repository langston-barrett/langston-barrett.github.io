# Survey of static reasoning in Haskell

<p>This post surveys a few techniques for achieving high confidence in
Haskell code <em>at type-checking time</em>. (It will not cover any aspects of
testing.) To compare the approaches, I'll implement a single interface
with each of them.</p>
<p>The surveyed techniques are fairly complicated. I'll try to explain a
bit about each, but please refer to their documentation for additional
background. This post will also assume familiarity with a lot of
Haskell: existential quantification
<code>(-XExistentialQuantification</code>, <code>-XGADTs</code>, or
<code>-XRank2Types</code>), existential quantification with higher-rank
polymorphism (<code>-XRankNTypes</code>), safe coercions
(<code>Data.Coerce</code>), phantom types, constraint kinds
(<code>-XConstraintKinds</code>), GADTs, and data kinds
(<code>-XDataKinds</code> and <code>-XPolyKinds</code>).</p>
<p>This post probably should have included
<a href="https://github.com/plclub/hs-to-coq">hs-to-coq</a>, but I'm unfamiliar
with it and perfection is the enemy of completion.</p>
<h2 id="the-specification">The Specification</h2>
<p>The interface in question is for lists of key/value pairs, also known as
<em>association lists</em>. For the sake of brevity, we'll only require four
operations:</p>
<ul>
<li><code>empty</code>: An empty association list</li>
<li><code>insert</code>: Takes a key and value and inserts the pair into
the list</li>
<li><code>lookup</code>: Takes a key and returns a value associated with
it</li>
<li><code>fmap</code>: The association list type must be a functor over
the value type</li>
</ul>
<p>The point is to do a broad-strokes comparison, so we'll adopt a very
minimal specification, only requiring that</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#abb2bf;">forall k v assoc</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;"> lookup k (insert k v assoc) </span><span style="color:#adb7c9;">==</span><span style="color:#abb2bf;"> v
</span></code></pre>
<p>along with the usual functor laws. The asymptotics should be:</p>
<ul>
<li><code>empty</code>: <em>O(1)</em></li>
<li><code>insert</code>: <em>O(1)</em></li>
<li><code>lookup</code>: <em>O(n)</em></li>
<li><code>fmap f</code>: <em>O(n)</em> if <code>f</code> takes constant time</li>
</ul>
<h2 id="vanilla-haskell">Vanilla Haskell</h2>
<p>First, let's see what an implementation in &quot;plain Haskell&quot; might look
like:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> DeriveFunctor #-}
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">module </span><span style="color:#abb2bf;">Vanilla
</span><span style="color:#abb2bf;">  ( </span><span style="color:#cd74e8;">Assoc
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">empty
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">insert
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">lookup
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">lookupMaybe
</span><span style="color:#abb2bf;">  ) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Prelude </span><span style="color:#cd74e8;">hiding </span><span style="color:#abb2bf;">(</span><span style="color:#5cb3fa;">lookup</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">newtype </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> k v </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> [(k, v)]
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">deriving </span><span style="color:#db9d63;">Functor
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">empty </span><span style="color:#cd74e8;">:: Assoc </span><span style="color:#eb6772;">k v
</span><span style="color:#abb2bf;">empty </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Assoc []
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">insert </span><span style="color:#cd74e8;">:: </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">v </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">k v </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">k v
</span><span style="color:#abb2bf;">insert k v (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> assoc) </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> ((k, v)</span><span style="color:#adb7c9;">:</span><span style="color:#abb2bf;">assoc)
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">lookup </span><span style="color:#cd74e8;">:: Eq </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt; </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">k v </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">v
</span><span style="color:#abb2bf;">lookup k (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> assoc) </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> assoc </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">[] </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> error </span><span style="color:#9acc76;">&quot;Failure!&quot;
</span><span style="color:#abb2bf;">    ((k&#39;, v)</span><span style="color:#adb7c9;">:</span><span style="color:#abb2bf;">rest) </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">if</span><span style="color:#abb2bf;"> k </span><span style="color:#adb7c9;">==</span><span style="color:#abb2bf;"> k&#39;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">then</span><span style="color:#abb2bf;"> v
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">else</span><span style="color:#abb2bf;"> lookup k (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> rest)
</span></code></pre>
<p>Short and sweet! Using the API is pretty simple, too:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">test </span><span style="color:#cd74e8;">:: String
</span><span style="color:#abb2bf;">test </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> lookup </span><span style="color:#db9d63;">2</span><span style="color:#abb2bf;"> (insert </span><span style="color:#db9d63;">2 </span><span style="color:#9acc76;">&quot;&quot;</span><span style="color:#abb2bf;"> empty)
</span></code></pre>
<p>But there's one problem: <code>lookup</code> calls <code>error</code>,
which can cause the program to fail at run-time. How can we gain more
assurance that a program written using this interface won't
unexpectedly fail? A common answer would be to reify the partiality in
the return type, e.g., with <code>Maybe</code> or <code>Either</code>:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">lookupMaybe </span><span style="color:#cd74e8;">:: Eq </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt; </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">k v </span><span style="color:#cd74e8;">-&gt; Maybe </span><span style="color:#eb6772;">v
</span><span style="color:#abb2bf;">lookupMaybe k (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> assoc) </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> assoc </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">[] </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Nothing
</span><span style="color:#abb2bf;">    ((k&#39;, v)</span><span style="color:#adb7c9;">:</span><span style="color:#abb2bf;">rest) </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">if</span><span style="color:#abb2bf;"> k </span><span style="color:#adb7c9;">==</span><span style="color:#abb2bf;"> k&#39;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">then </span><span style="color:#db9d63;">Just</span><span style="color:#abb2bf;"> v
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">else</span><span style="color:#abb2bf;"> lookupMaybe k (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> rest)
</span></code></pre>
<p>This amounts to passing the buck. Every caller of
<code>lookupMaybe</code> has to decide how to handle the
<code>Nothing</code> case; they can choose to &quot;infect&quot; their own
return type with partiality, or to risk a run-time error by using a
partial function like <code>fromJust :: Maybe a -&gt; a</code>.</p>
<p>In general, API authors choose between four options to deal with
partiality:<sup class="footnote-reference"><a href="#1">1</a></sup></p>
<ol>
<li>Run-time failure, as in <code>lookup</code></li>
<li>Returning a &quot;default&quot; value, as in a division function that
returns zero when given a zero divisor</li>
<li>Reifying the partiality in the return type, as in
<code>lookupMaybe</code></li>
<li>Restricting the function's domain, e.g.,
<code>head :: NonEmpty a -&gt; a</code></li>
</ol>
<p>What if we want to the avoid runtime failure in (1), the ambiguity of
(2), and give callers more flexibility than (3)? (In the
<code>lookup</code> example, it's not even clear that (4) is at all
applicable.) Well hold on to your hats, because there are at least four
different ways to do it and they all involve quite a bit of type-system
tomfoolery.</p>
<h2 id="smart-constructors-and-the-existential-trick">Smart Constructors and the Existential Trick</h2>
<p>Types are the main tool that Haskell programmers use to get static
guarantees about their programs. But type signatures like
<code>Int -&gt; Bool</code> encode statements about <em>sets</em> of values (in
this case, this is a function that will take <em>any</em> <code>Int</code> as
an input), whereas the precondition of <code>lookup</code> is a
relationship between the <em>particular values</em> of the key and association
list. <code>lookup</code> requires that <em>this</em> key is present in <em>this
specific association list</em>. We need some way to attach unique type-level
names to each association list, and to tie keys to particular names.</p>
<p>First, we'll add a type variable <code>name</code> to both parameters
that acts as a unique identifier for the association list.
<code>Assoc name k v</code> is an association list with name
<code>name</code>, and <code>Key name k</code> is a key into the
association list with name <code>name</code>.</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> DeriveFunctor #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> ExistentialQuantification #-}
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">module </span><span style="color:#abb2bf;">Smart
</span><span style="color:#abb2bf;">  ( </span><span style="color:#cd74e8;">Assoc
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">Key
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">SomeAssoc</span><span style="color:#5cb3fa;">(..)
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">empty
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">insert
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">isKey
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">lookup
</span><span style="color:#abb2bf;">  ) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Prelude </span><span style="color:#cd74e8;">hiding </span><span style="color:#abb2bf;">(</span><span style="color:#5cb3fa;">lookup</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">newtype </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> name k v </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> [(k, v)]
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">deriving </span><span style="color:#db9d63;">Functor
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">newtype </span><span style="color:#db9d63;">Key</span><span style="color:#abb2bf;"> name k </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Key</span><span style="color:#abb2bf;"> k
</span></code></pre>
<p>The question is now: How do we make sure each new <code>Assoc</code> has
a fresh <code>name</code> and can't be confused with any other
<code>Assoc</code>? The trick that makes this work is <em>existential
quantification</em>. Consider the type <code>Something</code>:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">Something </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> forall a</span><span style="color:#adb7c9;">. </span><span style="color:#db9d63;">Something</span><span style="color:#abb2bf;"> a
</span></code></pre>
<p>Say that I give you two <code>Something</code> values, and you pattern
match on them:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">you </span><span style="color:#cd74e8;">:: Something -&gt; Something -&gt; Int
</span><span style="color:#abb2bf;">you (</span><span style="color:#db9d63;">Something</span><span style="color:#abb2bf;"> x) (</span><span style="color:#db9d63;">Something</span><span style="color:#abb2bf;"> y) </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> _
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">me </span><span style="color:#cd74e8;">:: Int
</span><span style="color:#abb2bf;">me </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> you (</span><span style="color:#db9d63;">Something ()</span><span style="color:#abb2bf;">) (</span><span style="color:#db9d63;">Something </span><span style="color:#9acc76;">&quot;foo&quot;</span><span style="color:#abb2bf;">)
</span></code></pre>
<p>What can you do with the data I've given you? In short, pretty much
nothing. You can't use <code>x</code> and <code>y</code> in any
meaningful way, they have completely unknown and unrelated types (GHC
will name their types something like <code>a</code> and
<code>a1</code>). In other words, we've given <code>x</code> and
<code>y</code> <em>unique type-level labels</em>. The same trick will work for
<code>Assoc</code>!</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">SomeAssoc</span><span style="color:#abb2bf;"> k v </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> forall name</span><span style="color:#adb7c9;">. </span><span style="color:#db9d63;">SomeAssoc</span><span style="color:#abb2bf;"> (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> name k v)
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">empty </span><span style="color:#cd74e8;">:: SomeAssoc </span><span style="color:#eb6772;">k v
</span><span style="color:#abb2bf;">empty </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">SomeAssoc</span><span style="color:#abb2bf;"> (</span><span style="color:#db9d63;">Assoc []</span><span style="color:#abb2bf;">)
</span></code></pre>
<p>Since we didn't export the constructor of <code>Assoc</code> but we
<em>did</em> export that of <code>SomeAssoc</code>, the only way to make a new
association list is to pattern match on the existentially-quantified
<code>empty</code> value, which invents a new type-level
<code>name</code> for each <code>Assoc</code>.</p>
<p><code>insert</code> and <code>lookup</code> much the same, modulo
slightly changed types:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">insert </span><span style="color:#cd74e8;">:: </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">v </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">name k v </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">name k v
</span><span style="color:#abb2bf;">insert k v (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> assoc) </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> ((k, v)</span><span style="color:#adb7c9;">:</span><span style="color:#abb2bf;">assoc)
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">lookup </span><span style="color:#cd74e8;">:: Eq </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt; Key </span><span style="color:#eb6772;">name k </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">name k v </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">v
</span><span style="color:#abb2bf;">lookup (</span><span style="color:#db9d63;">Key</span><span style="color:#abb2bf;"> k) (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> assoc) </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> assoc </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">[] </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> error </span><span style="color:#9acc76;">&quot;Impossible&quot;
</span><span style="color:#abb2bf;">    ((k&#39;, v)</span><span style="color:#adb7c9;">:</span><span style="color:#abb2bf;">rest) </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">if</span><span style="color:#abb2bf;"> k </span><span style="color:#adb7c9;">==</span><span style="color:#abb2bf;"> k&#39;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">then</span><span style="color:#abb2bf;"> v
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">else</span><span style="color:#abb2bf;"> lookup (</span><span style="color:#db9d63;">Key</span><span style="color:#abb2bf;"> k) (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> rest)
</span></code></pre>
<p>It <em>looks</em> like <code>lookup</code> is still partial, but by carefully
controlling how clients get a <code>Key</code>, we can ensure that it's
total. And the only way we'll let them do so is with <code>isKey</code>
(note that the constructor of <code>Key</code>, like that of
<code>Assoc</code>, is not exported):</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">isKey </span><span style="color:#cd74e8;">:: Eq </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt; </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">name k v </span><span style="color:#cd74e8;">-&gt; Maybe</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Key </span><span style="color:#eb6772;">name k</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">isKey k (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> assoc) </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> assoc </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">[] </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Nothing
</span><span style="color:#abb2bf;">    ((k&#39;, _)</span><span style="color:#adb7c9;">:</span><span style="color:#abb2bf;">rest) </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">if</span><span style="color:#abb2bf;"> k </span><span style="color:#adb7c9;">==</span><span style="color:#abb2bf;"> k&#39;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">then </span><span style="color:#db9d63;">Just</span><span style="color:#abb2bf;"> (</span><span style="color:#db9d63;">Key</span><span style="color:#abb2bf;"> k)
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">else</span><span style="color:#abb2bf;"> isKey k (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> rest)
</span></code></pre>
<p>It's basically identical to <code>lookup</code>: it searches through
the list and only yields a <code>Key</code> if <code>k</code> really is
a key in the list. Since this is the only way to get a <code>Key</code>,
every <code>lookup</code> is guaranteed to succeed.</p>
<p>Here's an example usage:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">test </span><span style="color:#cd74e8;">:: String
</span><span style="color:#abb2bf;">test </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> empty </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">SomeAssoc</span><span style="color:#abb2bf;"> emp </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">let</span><span style="color:#abb2bf;"> assoc </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> insert </span><span style="color:#db9d63;">2 </span><span style="color:#9acc76;">&quot;&quot;</span><span style="color:#abb2bf;"> emp
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">in case</span><span style="color:#abb2bf;"> isKey </span><span style="color:#db9d63;">2</span><span style="color:#abb2bf;"> assoc </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">           </span><span style="color:#db9d63;">Just</span><span style="color:#abb2bf;"> k </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> lookup k assoc
</span><span style="color:#abb2bf;">           </span><span style="color:#db9d63;">Nothing </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> error </span><span style="color:#9acc76;">&quot;not a key&quot;
</span></code></pre>
<p>Note that while <code>isKey</code> introduces a <code>Maybe</code>, the
actual <code>lookup</code> operation doesn't. You can, e.g., store keys
in a list and look them up later, without introducing partiality at the
lookup. This still isn't ideal; one way to work around it in some cases
would be to have <code>insert</code> return a <code>Key</code>.</p>
<h2 id="gadts-or-dependent-types">GADTs, or Dependent Types</h2>
<p><em>Dependent types</em> are (roughly speaking) types that can mention values.
Haskell doesn't have &quot;full&quot; dependent types, but GADTs make the type
system quite expressive. Let's see what we can do with them!</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> DataKinds #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> GADTs #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> LambdaCase #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> PolyKinds #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> TypeOperators #-}
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">module </span><span style="color:#abb2bf;">GADT
</span><span style="color:#abb2bf;">  ( </span><span style="color:#cd74e8;">Assoc
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">NatRepr</span><span style="color:#5cb3fa;">(..)
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">Key
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">empty
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">insert
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">isKey
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">lookup
</span><span style="color:#abb2bf;">  ) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Prelude </span><span style="color:#cd74e8;">hiding </span><span style="color:#abb2bf;">(</span><span style="color:#5cb3fa;">lookup</span><span style="color:#abb2bf;">)
</span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Data.Kind (</span><span style="color:#cd74e8;">Type</span><span style="color:#abb2bf;">)
</span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Data.Type.Equality (</span><span style="color:#cd74e8;">TestEquality</span><span style="color:#abb2bf;">(testEquality), (:~:)(Refl))
</span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">GHC.TypeLits (</span><span style="color:#cd74e8;">Nat</span><span style="color:#abb2bf;">, </span><span style="color:#5cb3fa;">type (+)</span><span style="color:#abb2bf;">)
</span></code></pre>
<p>For the sake of concreteness, we'll fix the keys to be natural numbers:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">NatRepr</span><span style="color:#abb2bf;"> (n </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">Nat</span><span style="color:#abb2bf;">) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">Zero </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">NatRepr 0
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">Succ </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">NatRepr</span><span style="color:#abb2bf;"> n </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">NatRepr</span><span style="color:#abb2bf;"> (n </span><span style="color:#adb7c9;">+ </span><span style="color:#db9d63;">1</span><span style="color:#abb2bf;">)
</span></code></pre>
<p><code>NatRepr</code> is a <em>singleton type</em> meaning each value has a
unique type. For example, <code>Zero :: NatRepr 0</code> and
<code>Succ Zero :: NatRepr 1</code>.</p>
<p>Just as <code>lookup</code> had an <code>Eq</code> constraint above,
<code>NatRepr</code> needs a <code>TestEquality</code> instance, which
<a href="https://hackage.haskell.org/package/base-4.17.0.0/docs/Data-Type-Equality.html#t:TestEquality">is similar but for
singletons</a>:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">instance TestEquality NatRepr where
</span><span style="color:#abb2bf;">  testEquality n m </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> (n, m) </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">      (</span><span style="color:#db9d63;">Succ</span><span style="color:#abb2bf;"> _, </span><span style="color:#db9d63;">Zero</span><span style="color:#abb2bf;">) </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Nothing
</span><span style="color:#abb2bf;">      (</span><span style="color:#db9d63;">Zero</span><span style="color:#abb2bf;">, </span><span style="color:#db9d63;">Succ</span><span style="color:#abb2bf;"> _) </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Nothing
</span><span style="color:#abb2bf;">      (</span><span style="color:#db9d63;">Zero</span><span style="color:#abb2bf;">, </span><span style="color:#db9d63;">Zero</span><span style="color:#abb2bf;">) </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Just Refl
</span><span style="color:#abb2bf;">      (</span><span style="color:#db9d63;">Succ</span><span style="color:#abb2bf;"> n&#39;, </span><span style="color:#db9d63;">Succ</span><span style="color:#abb2bf;"> m&#39;) </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> testEquality n&#39; m&#39; </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">          </span><span style="color:#db9d63;">Just Refl </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Just Refl
</span><span style="color:#abb2bf;">          </span><span style="color:#db9d63;">Nothing </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Nothing
</span></code></pre>
<p>The <code>Assoc</code> type carries a type-level list of its keys:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> (keys </span><span style="color:#adb7c9;">::</span><span style="color:#abb2bf;"> [</span><span style="color:#db9d63;">Nat</span><span style="color:#abb2bf;">]) (a </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">Type</span><span style="color:#abb2bf;">) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">Nil </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> &#39;</span><span style="color:#db9d63;">[]</span><span style="color:#abb2bf;"> a
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">Cons </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">NatRepr</span><span style="color:#abb2bf;"> n </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> a </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> keys a </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> (n &#39;</span><span style="color:#adb7c9;">:</span><span style="color:#abb2bf;"> keys) a
</span></code></pre>
<p>Because this is a GADT, we can no longer derive <code>Functor</code>, we
have to write it ourselves:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">instance Functor</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Assoc </span><span style="color:#eb6772;">keys</span><span style="color:#abb2bf;">) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">  fmap f </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">    </span><span style="color:#adb7c9;">\</span><span style="color:#cd74e8;">case
</span><span style="color:#abb2bf;">      </span><span style="color:#db9d63;">Nil </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Nil
</span><span style="color:#abb2bf;">      </span><span style="color:#db9d63;">Cons</span><span style="color:#abb2bf;"> n a rest </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Cons</span><span style="color:#abb2bf;"> n (f a) (fmap f rest)
</span></code></pre>
<p><code>empty</code> has an empty type-level list of keys:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">empty </span><span style="color:#cd74e8;">:: Assoc</span><span style="color:#abb2bf;"> &#39;[] </span><span style="color:#eb6772;">a
</span><span style="color:#abb2bf;">empty </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Nil
</span></code></pre>
<p><code>insert</code> adds one key to the front of the type-level list. In
fact, <code>insert</code> is just <code>Cons</code>:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">insert </span><span style="color:#cd74e8;">:: NatRepr </span><span style="color:#eb6772;">n </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">a </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">keys a </span><span style="color:#cd74e8;">-&gt; Assoc</span><span style="color:#abb2bf;"> (</span><span style="color:#eb6772;">n</span><span style="color:#abb2bf;"> &#39;: </span><span style="color:#eb6772;">keys</span><span style="color:#abb2bf;">) </span><span style="color:#eb6772;">a
</span><span style="color:#abb2bf;">insert </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Cons
</span></code></pre>
<p>As in the smart constructor approach, we use a new type <code>Key</code>
to track the relationship between a key and an association list. Unlike
the smart constructor approach, we don't have to trust the
implementation of <code>isKey</code>; the types force it to be correct.</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">Key</span><span style="color:#abb2bf;"> (n </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">Nat</span><span style="color:#abb2bf;">) (keys </span><span style="color:#adb7c9;">::</span><span style="color:#abb2bf;"> [</span><span style="color:#db9d63;">Nat</span><span style="color:#abb2bf;">]) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">KeyHere </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">Key</span><span style="color:#abb2bf;"> n (n &#39;</span><span style="color:#adb7c9;">:</span><span style="color:#abb2bf;"> l)
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">KeyThere </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">Key</span><span style="color:#abb2bf;"> n keys </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Key</span><span style="color:#abb2bf;"> n (m &#39;</span><span style="color:#adb7c9;">:</span><span style="color:#abb2bf;"> keys)
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">isKey </span><span style="color:#cd74e8;">:: NatRepr </span><span style="color:#eb6772;">n </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">keys a </span><span style="color:#cd74e8;">-&gt; Maybe</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Key </span><span style="color:#eb6772;">n keys</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">isKey n assoc </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> assoc </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Nil </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Nothing
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Cons</span><span style="color:#abb2bf;"> m _ rest </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> testEquality n m </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">        </span><span style="color:#db9d63;">Just Refl </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Just KeyHere
</span><span style="color:#abb2bf;">        </span><span style="color:#db9d63;">Nothing </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">          </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> isKey n rest </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">            </span><span style="color:#db9d63;">Nothing </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Nothing
</span><span style="color:#abb2bf;">            </span><span style="color:#db9d63;">Just</span><span style="color:#abb2bf;"> key </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Just</span><span style="color:#abb2bf;"> (</span><span style="color:#db9d63;">KeyThere</span><span style="color:#abb2bf;"> key)
</span></code></pre>
<p>In <code>lookup</code>, GHC's pattern match checker can tell that if
there's a <code>Key n keys</code>, then the type-level list
<code>keys</code> can't be empty, so there's no need to handle the
<code>Nil</code> case:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">lookup </span><span style="color:#cd74e8;">:: Key </span><span style="color:#eb6772;">n keys </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">keys a </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">a
</span><span style="color:#abb2bf;">lookup key assoc </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> (key, assoc) </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">    (</span><span style="color:#db9d63;">KeyHere</span><span style="color:#abb2bf;">, </span><span style="color:#db9d63;">Cons</span><span style="color:#abb2bf;"> _ a _) </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> a
</span><span style="color:#abb2bf;">    (</span><span style="color:#db9d63;">KeyThere</span><span style="color:#abb2bf;"> key&#39;, </span><span style="color:#db9d63;">Cons</span><span style="color:#abb2bf;"> _ _ rest) </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> lookup key&#39; rest
</span></code></pre>
<p>Here's an example usage:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">test </span><span style="color:#cd74e8;">:: String
</span><span style="color:#abb2bf;">test </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> isKey two assoc </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Just</span><span style="color:#abb2bf;"> k </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> lookup k assoc
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Nothing </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> error </span><span style="color:#9acc76;">&quot;not a key&quot;
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">    two </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Succ</span><span style="color:#abb2bf;"> (</span><span style="color:#db9d63;">Succ Zero</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">    assoc </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> insert two </span><span style="color:#9acc76;">&quot;&quot;</span><span style="color:#abb2bf;"> empty
</span></code></pre>
<h2 id="ghosts-of-departed-proofs">Ghosts of Departed Proofs</h2>
<p><a href="https://dl.acm.org/doi/abs/10.1145/3242744.3242755">The Ghosts of Departed Proofs (GDP)
paper</a>
(<a href="http://kataskeue.com/gdp.pdf">PDF</a>) outlined several insights that
supercharge the smart constructor/existential trick above.</p>
<p>It's worth noting that I'm not an expert in GDP.</p>
<h3 id="gdp-infrastructure">GDP Infrastructure</h3>
<p>The following introduction to the core GDP infrastructure is fairly
cursory, please check out the paper for more information. I'm defining
all this here to make this post self-contained, but the combinators in
this module are available in the <code>gdp</code> package <a href="https://hackage.haskell.org/package/gdp">on
Hackage</a>.</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> ConstraintKinds #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> DefaultSignatures #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> DeriveFunctor #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> FlexibleContexts #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> FlexibleInstances #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> FunctionalDependencies #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> MultiParamTypeClasses #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> RankNTypes #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> TypeOperators #-}
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">module </span><span style="color:#abb2bf;">GDP.Named
</span><span style="color:#abb2bf;">  ( </span><span style="color:#cd74e8;">Named
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">name
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">the
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">SuchThat
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">suchThat
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">Defn
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">Proof
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">axiom
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">type (--&gt;)
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">implElim
</span><span style="color:#abb2bf;">  ) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Prelude </span><span style="color:#cd74e8;">hiding </span><span style="color:#abb2bf;">(</span><span style="color:#5cb3fa;">lookup</span><span style="color:#abb2bf;">)
</span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Data.Coerce (</span><span style="color:#cd74e8;">Coercible</span><span style="color:#abb2bf;">, </span><span style="color:#5cb3fa;">coerce</span><span style="color:#abb2bf;">)
</span></code></pre>
<p>First, the <code>Named</code> type and <code>name</code> function
generalize the existential introduction of type-level names for values,
using an equivalence between rank-2 types (the <code>forall</code> in
the second parameter to <code>name</code>) and existential types:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">-- | Called @~~@ in GDP.
</span><span style="color:#cd74e8;">newtype </span><span style="color:#db9d63;">Named</span><span style="color:#abb2bf;"> name a </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Named</span><span style="color:#abb2bf;"> a
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">deriving </span><span style="color:#db9d63;">Functor
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">name </span><span style="color:#cd74e8;">:: </span><span style="color:#eb6772;">a </span><span style="color:#cd74e8;">-&gt;</span><span style="color:#abb2bf;"> (</span><span style="color:#eb6772;">forall name</span><span style="color:#abb2bf;">. </span><span style="color:#cd74e8;">Named </span><span style="color:#eb6772;">name a </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">t</span><span style="color:#abb2bf;">) </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">t
</span><span style="color:#abb2bf;">name x k </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> coerce k x
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">INLINE</span><span style="color:#abb2bf;"> name #-}
</span></code></pre>
<p>To extract a <code>Named</code> value, clients use <code>the</code>:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">class </span><span style="color:#9acc76;">The </span><span style="color:#eb6772;">x a</span><span style="color:#abb2bf;"> | </span><span style="color:#eb6772;">x</span><span style="color:#abb2bf;"> -&gt; </span><span style="color:#eb6772;">a </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">  </span><span style="color:#5cb3fa;">the </span><span style="color:#cd74e8;">:: </span><span style="color:#eb6772;">x </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">a
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">default</span><span style="color:#abb2bf;"> the </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">Coercible</span><span style="color:#abb2bf;"> x a </span><span style="color:#adb7c9;">=&gt;</span><span style="color:#abb2bf;"> x </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> a
</span><span style="color:#abb2bf;">  the </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> coerce
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">instance The</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Named </span><span style="color:#eb6772;">name a</span><span style="color:#abb2bf;">) </span><span style="color:#eb6772;">a </span><span style="color:#cd74e8;">where
</span></code></pre>
<p>Modules can give type-level names to functions using <code>Defn</code>
(demonstrated later):</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">Defn </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Defn
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">type </span><span style="color:#db9d63;">Defining</span><span style="color:#abb2bf;"> name </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> (</span><span style="color:#db9d63;">Coercible Defn</span><span style="color:#abb2bf;"> name, </span><span style="color:#db9d63;">Coercible</span><span style="color:#abb2bf;"> name </span><span style="color:#db9d63;">Defn</span><span style="color:#abb2bf;">)
</span></code></pre>
<p>Type-level propositions are called <code>Proof</code>, and can be
manipulated with axioms like <code>implElim</code>:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">Proof</span><span style="color:#abb2bf;"> a </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Proof  </span><span style="font-style:italic;color:#5f697a;">-- called QED in GDP
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">axiom </span><span style="color:#cd74e8;">:: Proof </span><span style="color:#eb6772;">a
</span><span style="color:#abb2bf;">axiom </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Proof
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">data</span><span style="color:#abb2bf;"> p </span><span style="font-style:italic;color:#5f697a;">--&gt; q
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">implElim </span><span style="color:#cd74e8;">:: Proof</span><span style="color:#abb2bf;"> (</span><span style="color:#eb6772;">p </span><span style="font-style:italic;color:#5f697a;">--&gt; q) -&gt; Proof p -&gt; Proof q
</span><span style="color:#abb2bf;">implElim _ _ </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> axiom
</span></code></pre>
<p>Type-level propositions can be attached to values with
<code>SuchThat</code> (which can also be cast away with
<code>the</code>):</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">-- | Called @:::@ in GDP.
</span><span style="color:#cd74e8;">newtype </span><span style="color:#db9d63;">SuchThat</span><span style="color:#abb2bf;"> p a </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">SuchThat</span><span style="color:#abb2bf;"> a
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">deriving </span><span style="color:#db9d63;">Functor
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">instance The</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">SuchThat </span><span style="color:#eb6772;">p a</span><span style="color:#abb2bf;">) </span><span style="color:#eb6772;">a </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">suchThat </span><span style="color:#cd74e8;">:: </span><span style="color:#eb6772;">a </span><span style="color:#cd74e8;">-&gt; Proof </span><span style="color:#eb6772;">p </span><span style="color:#cd74e8;">-&gt; SuchThat </span><span style="color:#eb6772;">p a
</span><span style="color:#abb2bf;">suchThat x _ </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> coerce x
</span></code></pre>
<h3 id="gdp-implementation-of-association-lists">GDP Implementation of Association Lists</h3>
<p>Now let's take a look at using those tools to provide more assurance
for the <code>Assoc</code> API. Happily, we can directly reuse
<code>Assoc</code> and <code>empty</code> from the vanilla Haskell
implementation!</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> DeriveFunctor #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> ExplicitNamespaces #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> RoleAnnotations #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> TypeOperators #-}
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">module </span><span style="color:#abb2bf;">GDP
</span><span style="color:#abb2bf;">  ( </span><span style="color:#cd74e8;">Assoc
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">Vanilla</span><span style="color:#abb2bf;">.</span><span style="color:#5cb3fa;">empty
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">IsKey
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">Insert
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">insert
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">lookup
</span><span style="color:#abb2bf;">  ) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">import           </span><span style="color:#abb2bf;">Prelude </span><span style="color:#cd74e8;">hiding </span><span style="color:#abb2bf;">(</span><span style="color:#5cb3fa;">lookup</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">import qualified </span><span style="color:#abb2bf;">GDP.Named </span><span style="color:#cd74e8;">as </span><span style="color:#abb2bf;">GDP
</span><span style="color:#cd74e8;">import           </span><span style="color:#abb2bf;">GDP.Named (</span><span style="color:#5cb3fa;">type (--&gt;)</span><span style="color:#abb2bf;">)
</span><span style="color:#cd74e8;">import           </span><span style="color:#abb2bf;">GDP.Maybe (</span><span style="color:#cd74e8;">IsJust</span><span style="color:#abb2bf;">)
</span><span style="color:#cd74e8;">import qualified </span><span style="color:#abb2bf;">GDP.Maybe </span><span style="color:#cd74e8;">as </span><span style="color:#abb2bf;">GDP
</span><span style="color:#cd74e8;">import qualified </span><span style="color:#abb2bf;">Vanilla </span><span style="color:#cd74e8;">as </span><span style="color:#abb2bf;">Vanilla
</span><span style="color:#cd74e8;">import           </span><span style="color:#abb2bf;">Vanilla (</span><span style="color:#cd74e8;">Assoc</span><span style="color:#abb2bf;">)
</span></code></pre>
<p>Instead of a separate <code>Key</code> type, we create a type-level
proposition <code>IsKey</code>. A
<code>GPD.Proof (IsKey kn assocn)</code> means that the key of type
<code>GDP.Named kn k</code> is present in the association list of type
<code>GDP.Named assocn (Assoc k v)</code>.</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">-- | @kn@ is a key of association list @assocn@
</span><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">IsKey</span><span style="color:#abb2bf;"> kn assocn
</span><span style="color:#cd74e8;">type</span><span style="color:#abb2bf;"> role </span><span style="color:#db9d63;">IsKey</span><span style="color:#abb2bf;"> nominal nominal
</span></code></pre>
<p><code>lookup</code> takes a key with an additional <code>IsKey</code>
proof as a parameter and then just shells out to the underlying vanilla
Haskell <code>lookup</code> implementation. The return type and the
<code>Lookup</code> newtype will be explained in just a moment.</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">-- | Type-level name of &#39;lookup&#39; for use in lemmas.
</span><span style="color:#cd74e8;">newtype </span><span style="color:#db9d63;">Lookup</span><span style="color:#abb2bf;"> kn assocn </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Lookup GDP</span><span style="color:#adb7c9;">.</span><span style="color:#db9d63;">Defn
</span><span style="color:#cd74e8;">type</span><span style="color:#abb2bf;"> role </span><span style="color:#db9d63;">Lookup</span><span style="color:#abb2bf;"> nominal nominal
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">lookup </span><span style="color:#cd74e8;">::
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">Eq </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt;
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">SuchThat</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">IsKey </span><span style="color:#eb6772;">kn assocn</span><span style="color:#abb2bf;">) (</span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named </span><span style="color:#eb6772;">kn k</span><span style="color:#abb2bf;">) </span><span style="color:#cd74e8;">-&gt;
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named </span><span style="color:#eb6772;">assocn</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Assoc </span><span style="color:#eb6772;">k v</span><span style="color:#abb2bf;">) </span><span style="color:#cd74e8;">-&gt;
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Lookup </span><span style="color:#eb6772;">kn assocn</span><span style="color:#abb2bf;">) </span><span style="color:#eb6772;">v
</span><span style="color:#abb2bf;">lookup k assoc </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">defn (</span><span style="color:#db9d63;">Vanilla</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">lookup (</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the (</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the k)) (</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the assoc))
</span></code></pre>
<p><code>insert</code> works much the same way, but it doesn't have any
preconditions and so doesn't use <code>SuchThat</code>:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">-- | Type-level name of &#39;insert&#39; for use in lemmas.
</span><span style="color:#cd74e8;">newtype </span><span style="color:#db9d63;">Insert</span><span style="color:#abb2bf;"> kn vn assocn </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Insert GDP</span><span style="color:#adb7c9;">.</span><span style="color:#db9d63;">Defn
</span><span style="color:#cd74e8;">type</span><span style="color:#abb2bf;"> role </span><span style="color:#db9d63;">Insert</span><span style="color:#abb2bf;"> nominal nominal nominal
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">insert </span><span style="color:#cd74e8;">::
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named </span><span style="color:#eb6772;">kn k </span><span style="color:#cd74e8;">-&gt;
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named </span><span style="color:#eb6772;">vn v </span><span style="color:#cd74e8;">-&gt;
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named </span><span style="color:#eb6772;">assocn</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Assoc </span><span style="color:#eb6772;">k v</span><span style="color:#abb2bf;">) </span><span style="color:#cd74e8;">-&gt;
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Insert </span><span style="color:#eb6772;">kn vn assocn</span><span style="color:#abb2bf;">) (</span><span style="color:#cd74e8;">Assoc </span><span style="color:#eb6772;">k v</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">insert k v assoc </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">defn (</span><span style="color:#db9d63;">Vanilla</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">insert (</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the k) (</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the v) (</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the assoc))
</span></code></pre>
<p>So how do clients construct a
<code>GDP.SuchThat (IsKey kn assocn) (GDP.Named kn k)</code> to pass to
<code>lookup</code>? One of the nice parts of GDP is that library
authors can determine how clients reason about propositions they define,
like <code>IsKey</code>. In particular, library authors can introduce
type-level names for their API functions like <code>Lookup</code> and
<code>Insert</code>, and export axioms that describe how the API relates
to the propositions.</p>
<p>One way to know that a key is in a map is if we just inserted that key.
We can express this fact by exporting an axiom:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">insertIsKey </span><span style="color:#cd74e8;">:: GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Proof</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">IsKey </span><span style="color:#eb6772;">kn</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Insert </span><span style="color:#eb6772;">kn vn assocn</span><span style="color:#abb2bf;">))
</span><span style="color:#abb2bf;">insertIsKey </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">axiom
</span></code></pre>
<p>With that lemma, here's an example use of this safe API:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">test </span><span style="color:#cd74e8;">:: String
</span><span style="color:#abb2bf;">test </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">name </span><span style="color:#db9d63;">Vanilla</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">empty </span><span style="color:#adb7c9;">$ \</span><span style="color:#abb2bf;">emp </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">name (</span><span style="color:#db9d63;">2 </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">Int</span><span style="color:#abb2bf;">) </span><span style="color:#adb7c9;">$ \</span><span style="color:#abb2bf;">k </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">      </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">name </span><span style="color:#9acc76;">&quot;&quot; </span><span style="color:#adb7c9;">$ \</span><span style="color:#abb2bf;">v </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">        </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the </span><span style="color:#adb7c9;">$
</span><span style="color:#abb2bf;">          lookup
</span><span style="color:#abb2bf;">            (k `</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">suchThat` insertIsKey)
</span><span style="color:#abb2bf;">            (insert k v emp)
</span></code></pre>
<p>We can also conclude <code>IsKey</code> when <code>lookupMaybe</code>
returns a <code>Just</code> value, kind of like what <code>isKey</code>
did in previous examples:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">-- | Type-level name of &#39;lookupMaybe&#39; for use in lemmas.
</span><span style="color:#cd74e8;">newtype </span><span style="color:#db9d63;">LookupMaybe</span><span style="color:#abb2bf;"> kn assocn </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">LookupMaybe GDP</span><span style="color:#adb7c9;">.</span><span style="color:#db9d63;">Defn
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">lookupMaybe </span><span style="color:#cd74e8;">::
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">Eq </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt;
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named </span><span style="color:#eb6772;">kn k </span><span style="color:#cd74e8;">-&gt;
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named </span><span style="color:#eb6772;">assocn</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Assoc </span><span style="color:#eb6772;">k v</span><span style="color:#abb2bf;">) </span><span style="color:#cd74e8;">-&gt;
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">LookupMaybe </span><span style="color:#eb6772;">kn assocn</span><span style="color:#abb2bf;">) (</span><span style="color:#cd74e8;">Maybe </span><span style="color:#eb6772;">v</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">lookupMaybe k assoc </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">defn (</span><span style="color:#db9d63;">Vanilla</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">lookupMaybe (</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the k) (</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the assoc))
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">lookupMaybeKey </span><span style="color:#cd74e8;">::
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Proof</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">IsJust</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">LookupMaybe </span><span style="color:#eb6772;">kn assocn</span><span style="color:#abb2bf;">) </span><span style="font-style:italic;color:#5f697a;">--&gt; IsKey kn assocn)
</span><span style="color:#abb2bf;">lookupMaybeKey </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">axiom
</span><span style="color:#abb2bf;">
</span><span style="color:#5cb3fa;">test2 </span><span style="color:#cd74e8;">:: String
</span><span style="color:#abb2bf;">test2 </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">name </span><span style="color:#db9d63;">Vanilla</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">empty </span><span style="color:#adb7c9;">$ \</span><span style="color:#abb2bf;">emp </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">name (</span><span style="color:#db9d63;">2 </span><span style="color:#adb7c9;">:: </span><span style="color:#db9d63;">Int</span><span style="color:#abb2bf;">) </span><span style="color:#adb7c9;">$ \</span><span style="color:#abb2bf;">k </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">      </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">name </span><span style="color:#9acc76;">&quot;&quot; </span><span style="color:#adb7c9;">$ \</span><span style="color:#abb2bf;">v </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">        </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the </span><span style="color:#adb7c9;">$
</span><span style="color:#abb2bf;">          </span><span style="color:#cd74e8;">let</span><span style="color:#abb2bf;"> assoc </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> insert k v emp
</span><span style="color:#abb2bf;">          </span><span style="color:#cd74e8;">in case </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">maybeCase (lookupMaybe k assoc) </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">               </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#db9d63;">IsNothing</span><span style="color:#abb2bf;"> _ </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> error </span><span style="color:#9acc76;">&quot;impossible&quot;
</span><span style="color:#abb2bf;">               </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#db9d63;">IsJust</span><span style="color:#abb2bf;"> isJustPf _ </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">                 lookup
</span><span style="color:#abb2bf;">                   (k `</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">suchThat` </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">implElim lookupMaybeKey isJustPf)
</span><span style="color:#abb2bf;">                   assoc
</span></code></pre>
<p>where <code>IsJust</code> and <code>maybeCase</code> are defined in
<code>GDP.Maybe</code>:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> ExplicitNamespaces #-}
</span><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> TypeOperators #-}
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">module </span><span style="color:#abb2bf;">GDP.Maybe
</span><span style="color:#abb2bf;">  ( </span><span style="color:#cd74e8;">IsNothing
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">IsJust
</span><span style="color:#abb2bf;">  , </span><span style="color:#cd74e8;">MaybeCase</span><span style="color:#abb2bf;">(IsNothing, IsJust)
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">maybeCase
</span><span style="color:#abb2bf;">  ) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">import qualified </span><span style="color:#abb2bf;">GDP.Named </span><span style="color:#cd74e8;">as </span><span style="color:#abb2bf;">GDP
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">IsJust</span><span style="color:#abb2bf;"> name
</span><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">IsNothing</span><span style="color:#abb2bf;"> name
</span><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">MaybeCase</span><span style="color:#abb2bf;"> name a
</span><span style="color:#abb2bf;">  </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">IsNothing</span><span style="color:#abb2bf;"> (</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#db9d63;">Proof</span><span style="color:#abb2bf;"> (</span><span style="color:#db9d63;">IsNothing</span><span style="color:#abb2bf;"> name))
</span><span style="color:#abb2bf;">  </span><span style="color:#adb7c9;">| </span><span style="color:#db9d63;">IsJust</span><span style="color:#abb2bf;"> (</span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#db9d63;">Proof</span><span style="color:#abb2bf;"> (</span><span style="color:#db9d63;">IsJust</span><span style="color:#abb2bf;"> name)) a
</span><span style="color:#abb2bf;">
</span><span style="font-style:italic;color:#5f697a;">-- | Called @classify@ in GDP.
</span><span style="color:#5cb3fa;">maybeCase </span><span style="color:#cd74e8;">:: GDP</span><span style="color:#abb2bf;">.</span><span style="color:#cd74e8;">Named </span><span style="color:#eb6772;">name</span><span style="color:#abb2bf;"> (</span><span style="color:#cd74e8;">Maybe </span><span style="color:#eb6772;">a</span><span style="color:#abb2bf;">) </span><span style="color:#cd74e8;">-&gt; MaybeCase </span><span style="color:#eb6772;">name a
</span><span style="color:#abb2bf;">maybeCase x </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">case </span><span style="color:#db9d63;">GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">the x </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Nothing </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">IsNothing GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">axiom
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Just</span><span style="color:#abb2bf;"> a </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">IsJust GDP</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">axiom a
</span></code></pre>
<p>Such code could clearly be defined once and for all in a library
somewhere, and probably even generated by Template Haskell.</p>
<h2 id="liquid-haskell">Liquid Haskell</h2>
<p><a href="https://ucsd-progsys.github.io/liquidhaskell-blog/">Liquid Haskell</a>
adds <em>refinement types</em> to Haskell, which are kind of like dependent
types. It operates as a GHC type-checking plugin, and doesn't affect
the runtime semantics of Haskell. I'm no Liquid Haskell expert, but
luckily <a href="http://ucsd-progsys.github.io/lh-workshop/05-case-study-eval.html">one of the case studies in the
documentation</a>
is on association lists. What follows is a slight adaptation.</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#abb2bf;">{-# </span><span style="color:#cd74e8;">LANGUAGE</span><span style="color:#abb2bf;"> LambdaCase #-}
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">module </span><span style="color:#abb2bf;">Liquid
</span><span style="color:#abb2bf;">  ( </span><span style="color:#cd74e8;">Assoc
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">empty
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">insert
</span><span style="color:#abb2bf;">  , </span><span style="color:#5cb3fa;">lookup
</span><span style="color:#abb2bf;">  ) </span><span style="color:#cd74e8;">where
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Prelude </span><span style="color:#cd74e8;">hiding </span><span style="color:#abb2bf;">(</span><span style="color:#5cb3fa;">lookup</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">import           </span><span style="color:#abb2bf;">Data.Set (</span><span style="color:#cd74e8;">Set</span><span style="color:#abb2bf;">)
</span><span style="color:#cd74e8;">import qualified </span><span style="color:#abb2bf;">Data.Set </span><span style="color:#cd74e8;">as </span><span style="color:#abb2bf;">Set
</span></code></pre>
<p>The <code>Assoc</code> type is isomorphic to the vanilla implementation:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#cd74e8;">data </span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> k v
</span><span style="color:#abb2bf;">  </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Nil
</span><span style="color:#abb2bf;">  </span><span style="color:#adb7c9;">| </span><span style="color:#db9d63;">Cons</span><span style="color:#abb2bf;"> k v (</span><span style="color:#db9d63;">Assoc</span><span style="color:#abb2bf;"> k v)
</span></code></pre>
<p><code>keys</code> retrieves the set of keys in the association list.
It's only used at the type level. Using <code>keys</code>, we can
refine the type of <code>empty</code> to state that <code>empty</code>
has no keys. Types like <code>{ v : T | C v }</code> should be read like
&quot;values of type <code>T</code> that additionally satisfy constraint
<code>C</code>&quot;. The base type <code>T</code> can almost always be
omitted, as it can be inferred from the vanilla-Haskell type signature.</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">{-@ measure keys @-}
</span><span style="color:#5cb3fa;">keys </span><span style="color:#cd74e8;">:: Ord </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt; Assoc </span><span style="color:#eb6772;">k v </span><span style="color:#cd74e8;">-&gt; Set </span><span style="color:#eb6772;">k
</span><span style="color:#abb2bf;">keys </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#adb7c9;">\</span><span style="color:#cd74e8;">case
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Nil </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">empty
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Cons</span><span style="color:#abb2bf;"> k _ rest </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">union (</span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">singleton k) (keys rest)
</span><span style="color:#abb2bf;">
</span><span style="font-style:italic;color:#5f697a;">{-@ empty :: { v : _ | keys v == Set.empty } @-}
</span><span style="color:#5cb3fa;">empty </span><span style="color:#cd74e8;">:: Assoc </span><span style="color:#eb6772;">k v
</span><span style="color:#abb2bf;">empty </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Nil
</span></code></pre>
<p>Similarly, the function <code>addKey</code> is used to refine the type
of <code>insert</code>:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">{-@ inline addKey @-}
</span><span style="color:#5cb3fa;">addKey </span><span style="color:#cd74e8;">:: Ord </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt; </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">k v </span><span style="color:#cd74e8;">-&gt; Set </span><span style="color:#eb6772;">k
</span><span style="color:#abb2bf;">addKey k kvs </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">union (</span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">singleton k) (keys kvs)
</span><span style="color:#abb2bf;">
</span><span style="font-style:italic;color:#5f697a;">{-@ insert :: k : _ -&gt; _ -&gt; assoc : _ -&gt; { v : _ | keys v = addKey k assoc } @-}
</span><span style="color:#5cb3fa;">insert </span><span style="color:#cd74e8;">:: </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">v </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">k v </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">k v
</span><span style="color:#abb2bf;">insert </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Cons
</span></code></pre>
<p>Finally, <code>has</code> is used to express the precondition on
<code>lookup</code>:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">{-@ inline has @-}
</span><span style="color:#5cb3fa;">has </span><span style="color:#cd74e8;">:: Ord </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt; </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">-&gt; Assoc </span><span style="color:#eb6772;">k v </span><span style="color:#cd74e8;">-&gt; Bool
</span><span style="color:#abb2bf;">has k assoc </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">member k (keys assoc)
</span><span style="color:#abb2bf;">
</span><span style="font-style:italic;color:#5f697a;">{-@ lookup :: assoc : _ -&gt; k : { key : _ | has key assoc } -&gt; v @-}
</span><span style="color:#5cb3fa;">lookup </span><span style="color:#cd74e8;">:: Eq </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt; Assoc </span><span style="color:#eb6772;">k v </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">-&gt; </span><span style="color:#eb6772;">v
</span><span style="color:#abb2bf;">lookup assoc k </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">case</span><span style="color:#abb2bf;"> assoc </span><span style="color:#cd74e8;">of
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Nil </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> error </span><span style="color:#9acc76;">&quot;Impossible&quot;
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Cons</span><span style="color:#abb2bf;"> k&#39; v rest </span><span style="color:#adb7c9;">-&gt;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">if</span><span style="color:#abb2bf;"> k </span><span style="color:#adb7c9;">==</span><span style="color:#abb2bf;"> k&#39;
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">then</span><span style="color:#abb2bf;"> v
</span><span style="color:#abb2bf;">      </span><span style="color:#cd74e8;">else</span><span style="color:#abb2bf;"> lookup rest k
</span></code></pre>
<p>Note that the order of parameters to <code>lookup</code> has to be
flipped so that <code>assoc</code> is in scope in the refinement type
for <code>k</code>.</p>
<p>Using this API looks almost exactly like it does for the vanilla
implementation:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="color:#5cb3fa;">test </span><span style="color:#cd74e8;">:: String
</span><span style="color:#abb2bf;">test </span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;"> lookup (insert </span><span style="color:#db9d63;">2 </span><span style="color:#9acc76;">&quot;&quot;</span><span style="color:#abb2bf;"> empty) </span><span style="color:#db9d63;">2
</span></code></pre>
<p>The type-checker will catch invalid calls to <code>lookup</code>:</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">src/Liquid.hs:58:36-45: error:
</span><span style="color:#abb2bf;">    Liquid Type Mismatch
</span><span style="color:#abb2bf;">    .
</span><span style="color:#abb2bf;">    The inferred type
</span><span style="color:#abb2bf;">      VV : {v : GHC.Types.Int | v == 3}
</span><span style="color:#abb2bf;">    .
</span><span style="color:#abb2bf;">    is not a subtype of the required type
</span><span style="color:#abb2bf;">      VV : {VV : GHC.Types.Int | Set_mem VV (Liquid.keys ?d)}
</span><span style="color:#abb2bf;">    .
</span><span style="color:#abb2bf;">    in the context
</span><span style="color:#abb2bf;">      ?b : {?b : (Liquid.Assoc GHC.Types.Int [GHC.Types.Char]) | Liquid.keys ?b == Set_empty 0}
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">      ?d : {?d : (Liquid.Assoc GHC.Types.Int [GHC.Types.Char]) | Liquid.keys ?d == Set_cup (Set_sng 2) (Liquid.keys ?b)}
</span><span style="color:#abb2bf;">   |
</span><span style="color:#abb2bf;">58 | test2 = lookup (insert 2 &quot;&quot; empty) (3 :: Int)
</span><span style="color:#abb2bf;">   |                                    ^^^^^^^^^^
</span></code></pre>
<h2 id="conclusions">Conclusions</h2>
<h3 id="smart-constructors-and-the-existential-trick-1">Smart Constructors and the Existential Trick</h3>
<p>Smart constructors and the existential trick are likely the most
accessible of all of the above techniques. They require only a single
fairly conservative extension to Haskell 2010
(<code>-XExistentialQuantification</code> or <code>-XRank2Types</code>).
However, the safety argument relies on the correct implementation of the
<code>newtype</code> abstraction by the library author; in this case it
would be easy enough to accidentally export the <code>Key</code>
constructor or provide some other way of constructing a <code>Key</code>
that violates the intended invariant. Also, a new <code>newtype</code>
and smart constructor generally have to be custom-built for each desired
safety property.</p>
<h3 id="gadts-or-dependent-types-1">GADTs, or Dependent Types</h3>
<p>Dependent types significantly reduce the possibility of programmer
error. Once appropriate definitions for <code>Assoc</code> and
<code>Key</code> are found, it is impossible for the library author to
mis-implement <code>isKey</code>. Like smart constructors and the
vanilla Haskell code, they require no external tooling nor libraries.
However, programming with dependently-typed techniques has its
downsides:</p>
<ul>
<li>It requires knowledge of lots of complex GHC extensions like GADTs,
type families (<code>-XTypeFamilies</code>), data kinds/polykinds,
and rank-n types.</li>
<li>Since types carry proof-relevant information (such as the
<code>keys</code> type index on the <code>Assoc</code> type), you
can end up with a ton of slight variations on a single interface
depending on the properties you need to prove.</li>
<li>It's hard to write dependently-typed code, so in practice you can
end up with inefficient code due to the difficulty of proving
efficient code correct. This is pretty much why this post focused on
association lists instead of a more efficient map structure: I think
it would probably be pretty hairy to write one up with GADTs.
Consider also that <code>Key</code> is linearly sized in the size of
the association map.</li>
<li>GADTs are not well-supported by existing infrastructure, so we
can't e.g. derive <code>TestEquality</code> nor
<code>Functor</code> instances, we have to write them ourselves.
It's also generally impossible even to hand-write instances for
hugely useful typeclasses like <code>Generic</code> and
<code>Data</code>. In fact, many important type classes relating to
singletons aren't even defined in <code>base</code> (see, e.g., the
typeclasses in <code>parameterized-utils</code>). Libraries like
<code>singletons</code> and <code>parameterized-utils</code> do have
Template Haskell techniques for generating instances for certain of
these classes.</li>
<li>Error messages involving dependently typed Haskell extensions
continue a venerable tradition of flummoxing learners.</li>
</ul>
<p>I'm very familiar with dependent types, which likely partially accounts
for why this list is so extensive.</p>
<h3 id="gdp">GDP</h3>
<p>The GDP approach is remarkably flexible. The ability to define arbitrary
lemmas about an API gives the API consumers a huge amount of power. For
example, it was possible to provide two ways to produce an
<code>IsKey</code> proof without changing the actual implementation.
Furthermore, the GDP approach was able to directly reuse the vanilla
Haskell implementation by simply providing wrappers with more
interesting type signatures.</p>
<p>On the other hand, understanding the GDP approach requires a good deal
of study. GDP also requires trusting the library author to provide sound
reasoning principles. The GDP paper outlines a few possible approaches
(including use of Liquid Haskell) to improve confidence in the exported
lemmas.</p>
<h3 id="liquid-haskell-1">Liquid Haskell</h3>
<p>Liquid Haskell was a bit difficult to install, some of the project's
packages had too-restrictive bounds (resulting in Cabal being unable to
find a build plan) whereas others had too-permissive bounds (resulting
in compilation failures when Cabal did find a plan). Generally, Liquid
Haskell is the unfortunate combination of an impressive amount of
infrastructure and code that's maintained mostly by academics. They've
done a great job of making it <em>fairly</em> easy to get started, but I
wouldn't rely on it for a commercial project for mundane reasons like
not being able to upgrade to the latest GHC until the Liquid Haskell
team releases a corresponding version of <code>liquid-base</code>.</p>
<p>Liquid Haskell sometimes requires you to write code in a particular way,
rejecting semantically equivalent (and arguably, clearer) rewrites. For
instance, I originally tried to write <code>keys</code> like so:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">{-@ measure keys @-}
</span><span style="color:#5cb3fa;">keys </span><span style="color:#cd74e8;">:: Ord </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt; Assoc </span><span style="color:#eb6772;">k v </span><span style="color:#cd74e8;">-&gt; Set </span><span style="color:#eb6772;">k
</span><span style="color:#abb2bf;">keys </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#adb7c9;">\</span><span style="color:#cd74e8;">case
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Nil </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">empty
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Cons</span><span style="color:#abb2bf;"> k _ rest </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">insert k (keys rest)
</span></code></pre>
<p>That didn't work, Liquid Haskell said
<code>Unbound symbol Data.Set.Internal.insert</code>. So I tried to
factor the insert-via-union into a <code>where</code> binding for the
sake of clarity like so:</p>
<pre data-lang="haskell" style="background-color:#2b303b;color:#6c7079;" class="language-haskell "><code class="language-haskell" data-lang="haskell"><span style="font-style:italic;color:#5f697a;">{-@ measure keys @-}
</span><span style="color:#5cb3fa;">keys </span><span style="color:#cd74e8;">:: Ord </span><span style="color:#eb6772;">k </span><span style="color:#cd74e8;">=&gt; Assoc </span><span style="color:#eb6772;">k v </span><span style="color:#cd74e8;">-&gt; Set </span><span style="color:#eb6772;">k
</span><span style="color:#abb2bf;">keys </span><span style="color:#adb7c9;">=
</span><span style="color:#abb2bf;">  </span><span style="color:#adb7c9;">\</span><span style="color:#cd74e8;">case
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Nil </span><span style="color:#adb7c9;">-&gt; </span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">empty
</span><span style="color:#abb2bf;">    </span><span style="color:#db9d63;">Cons</span><span style="color:#abb2bf;"> k _ rest </span><span style="color:#adb7c9;">-&gt;</span><span style="color:#abb2bf;"> setInsert k (keys rest)
</span><span style="color:#abb2bf;">  </span><span style="color:#cd74e8;">where</span><span style="color:#abb2bf;"> setInsert x </span><span style="color:#adb7c9;">= </span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">union (</span><span style="color:#db9d63;">Set</span><span style="color:#adb7c9;">.</span><span style="color:#abb2bf;">singleton x)
</span></code></pre>
<p>This resulted in
<code>Uh oh. Cannot create measure 'Liquid.keys': Does not have a case-of at the top-level</code>. If I understand correctly, this is
probably because Liquid Haskell analyzes code at the GHC Core level, so
it's sensitive to changes that look similar at the source level but
compile to different Core. Such errors are annoying, but I was able to
find workarounds whenever they came up. Just like &quot;dependent Haskell&quot;,
Liquid Haskell error messages leave a lot to be desired.</p>
<p>Like dependently typed Haskell and GDP, actually understanding Liquid
Haskell would take at least several hours if not days of study. That
being said, I was able to get started with this example in maybe an hour
or so using their documentation.</p>
<p>Aside from the type signatures, the Liquid Haskell implementation looks
pretty much exactly like the &quot;vanilla&quot; implementation. Remarkably, the
API is also almost identical, and users could choose whether or not to
use (and understand!) Liquid Haskell when consuming the API, unlike in
the other techniques.</p>
<p>As in the dependently-typed approach, less trust in the library author
is required.</p>
<p>Like GDP, I believe that Liquid Haskell provides the ability to export
lemmas for consumers to use in constructing proofs. Unlike GDP, I
believe all such lemmas can be machine-checked.</p>
<h3 id="comparison-and-takeaways">Comparison and Takeaways</h3>
<p>The following table summarizes the above remarks. A table can't have
much nuance and I'm not an expert in GDP nor Liquid Haskell, so the
ratings should be taken with a hefty grain of salt.</p>
<p>Key:</p>
<ul>
<li>Trust: How much you need to trust the library author, i.e., to what
degree are the claims of API safety machine-checked? (Lower is
better.)</li>
<li>Knowledge: How much do you need to learn to effectively apply this
technique? (Lower is better.)</li>
<li>Flexibility: How much flexibility do library consumers have to prove
that they're using the API safely? (Higher is better.)</li>
<li>Infrastructure: How much infrastructure is necessary to make the
approach work? (Lower is better.)</li>
<li>Reuse: How reusable are the components, e.g., if you needed to prove
a different property or construct a larger API? (Higher is better.)</li>
</ul>
<!--

Approach   Trust   Knowledge   Flexibility   Infrastructure   Reuse
---------- ------- ----------- ------------- ---------------- -------
Vanilla    n/a     Low         n/a           None             n/a
Smart      High    Med         Low           Low              Low
GADTs      Low     High        Med           Med              Med
GDP        High    High        High          High             High
Liquid     Low     High        High          Very high        High

-->
<p>TODO: Table got nerfed when changing blog software...</p>
<p>My overall take is that all of these techniques are under-utilized and
under-explored. GADTs/dependent types, GDP, and Liquid Haskell would all
be much easier to write if there were more widely-available libraries
for programming with them. Given the attention that dependent types have
received in the Haskell community, I think GDP and Liquid Haskell are
especially neglected.</p>
<p>As the table shows at a glance, these techniques offer a wide range of
benefits and drawbacks, which indicates that they're likely appropriate
for different use-cases. Broad adoption of several would enable Haskell
programmers to use techniques because they're appropriate to their
goals, rather than because they have a paucity of options.</p>
<h2 id="footnotes">Footnotes</h2>
<div class="footnote-definition" id="1"><sup class="footnote-definition-label">1</sup>
<p>These are taken from the Ghosts of Departed Proofs paper.</p>
</div>

  </div>
</body>
</html>
