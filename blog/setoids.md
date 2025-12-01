# A quick tutorial on setoids in Rocq

<p>A setoid is a type <code>T</code> and an
<a href="https://coq.inria.fr/library/Coq.Classes.RelationClasses.html#Equivalence"><code>equivalence</code></a>
<a href="https://coq.inria.fr/library/Coq.Relations.Relation_Definitions.html#relation"><code>relation</code></a>
<code>(=</code>) : T -&gt; T -&gt; Prop=. Coq has some built-in automation
facilities for working with setoids that can make your life a lot
easier.</p>
<h2 id="building-a-setoid">Building a setoid</h2>
<p>Let's suppose we wanted to implement a quick-and-dirty version of
finite sets on some type <code>A</code>. One option is to use
<code>list A</code>, but lists have two properties that get in the way:
ordering and duplication. Building a <code>Setoid</code> allows us to
abstract away these features, and consider two lists equivalent if they
have the same elements.</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">Context {A : Type}.
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">Definition equiv_list (l1 l2 : list A) : Prop :=
</span><span style="color:#abb2bf;">  ∀ a : A, In a l1 &lt;-&gt; In a l2.
</span></code></pre>
<p>To register our new equivalence with Coq and reap the benefits of
automation, we make <code>list A</code> an instance of the
<code>Setoid</code>
<a href="https://softwarefoundations.cis.upenn.edu/draft/qc-current/Typeclasses.html">typeclass</a>:</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">Instance ListSetoid : Setoid (list A) :=
</span><span style="color:#abb2bf;">  { equiv := equiv_list }.
</span><span style="color:#abb2bf;">Proof.
</span><span style="color:#abb2bf;">  split.
</span></code></pre>
<p>At this point, we're dropped into proof mode and our goal is to prove
that <code>equiv_list</code> is an equivalence relation. To see the full
proof, see <a href="https://gist.github.com/siddharthist/9462a99ebb6fb7acb4ddbfd6c3e66b9c">the Coq source for this
post</a>
(we use some setoid-related automation to prove this goal).</p>
<p>Immediately, we gain access to a few tactics that work for normal
equality, like
<a href="https://coq.inria.fr/refman/proof-engine/tactics.html#coq:tacn.reflexivity"><code>reflexivity</code></a>,
<a href="https://coq.inria.fr/refman/proof-engine/tactics.html#coq:tacn.symmetry"><code>symmetry</code></a>
(plus <code>symmetry in [...]</code>), and
<a href="https://coq.inria.fr/refman/proof-engine/tactics.html#coq:tacn.transitivity"><code>transitivity</code></a>.</p>
<h2 id="setoid-rewrite"><code>setoid_rewrite</code></h2>
<p>The #1 benefit to using setoids is access to the
<code>setoid_rewrite</code> tactic. Rewriting is one of the most
powerful features of the tactic language, and using setoids allows us to
expand its reach.</p>
<p>Suppose we have <code>l1 l2 : list A</code>. If we have
<code>l1 = l2</code> (where <code>=</code> is Coq's built-in equality),
we can replace <code>l1</code> with <code>l2</code> in all contexts:</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">Lemma hd_eq (l1 l2 : list A) : l1 = l2 -&gt; hd l1 = hd l2.
</span><span style="color:#abb2bf;">Proof.
</span><span style="color:#abb2bf;">  intros l1eql2.
</span><span style="color:#abb2bf;">  now rewrite l1eql2.
</span><span style="color:#abb2bf;">Qed.
</span></code></pre>
<p>This isn't true if we just know <code>l1 =</code> l2= (where
<code>==</code> is
<a href="https://coq.inria.fr/refman/user-extensions/syntax-extensions.html">notation</a>
for <code>list_equiv</code>). However, there are certain contexts in
which they are interchangeable. Suppose further that <code>A</code> has
decidable equality, and consider the following <code>remove</code>
function:</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">Context {deceq : ∀ x y : A, {x = y} + {x ≠ y}}.
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">Fixpoint remove (x : A) (lst : list A) : list A :=
</span><span style="color:#abb2bf;">  match lst with
</span><span style="color:#abb2bf;">  | nil =&gt; nil
</span><span style="color:#abb2bf;">  | cons y ys =&gt;
</span><span style="color:#abb2bf;">    match deceq x y with
</span><span style="color:#abb2bf;">    | left  _ =&gt; remove x ys
</span><span style="color:#abb2bf;">    | right _ =&gt; y :: remove x ys
</span><span style="color:#abb2bf;">    end
</span><span style="color:#abb2bf;">  end.
</span></code></pre>
<p>Since this removes <em>all</em> occurrences of <code>x</code> in
<code>lst</code>, we should be able to prove</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">∀ x l1 l2, l1 == l2 -&gt; remove x l1 = remove x l2
</span></code></pre>
<p>We state this lemma a bit oddly:</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">Instance removeProper : Proper (eq ==&gt; equiv ==&gt; equiv) remove.
</span></code></pre>
<p>This concisely states &quot;given two equal inputs <code>x y : A</code> and
two equivalent lists <code>l1 l2 : list A</code>,
<code>remove x l1</code> is equivalent to <code>remove y l2</code>&quot;. In
other words, <code>remove</code> respects equality on <code>A</code>
(trivially -- every Coq function respects equality) and the equivalence
relation <code>==</code> (AKA <code>equiv</code>) on
<code>list A</code>.</p>
<p>Once we have an <code>Instance</code> of <code>Proper</code>, we can use
<code>setoid_rewrite</code> to replace replace <code>remove x l1</code>
with <code>remove x l2</code>, even when they appear nested in the goal
statement:</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">Instance revProper : Proper (equiv ==&gt; equiv) (@rev A).
</span><span style="color:#abb2bf;">Proof.
</span><span style="color:#abb2bf;">  [...]
</span><span style="color:#abb2bf;">Qed.
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">Lemma remove_rev_remove {a b : A} {l1 l2 : list A} :
</span><span style="color:#abb2bf;">  l1 == l2 -&gt; rev (remove a l1) == rev (remove a l2).
</span><span style="color:#abb2bf;">Proof.
</span><span style="color:#abb2bf;">  intros H.
</span><span style="color:#abb2bf;">  now setoid_rewrite H.
</span><span style="color:#abb2bf;">Qed.
</span></code></pre>
<p>We can even compose <code>Proper</code> instances automatically:</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">Require Import Coq.Program.Basics.
</span><span style="color:#abb2bf;">Local Open Scope program_scope.
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">Instance rev_remove_Proper : ∀ a, Proper (equiv ==&gt; equiv) (@rev A ∘ remove a).
</span><span style="color:#abb2bf;">Proof.
</span><span style="color:#abb2bf;">  apply _.
</span><span style="color:#abb2bf;">Qed.
</span></code></pre>
<p>The benefits of setoid rewriting continue to increase with the
complexity of the goal.</p>

  </div>
</body>
</html>
