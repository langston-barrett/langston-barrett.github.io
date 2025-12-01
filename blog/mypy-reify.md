# Fun with mypy: reifying runtime relations on types

<p>I'm a big fan of type checkers for Python, like
<a href="http://mypy-lang.org/">Mypy</a>. One fun aspect of these tools is that
their type systems tend to have features that reflect the dynamic nature
of Python, like <a href="https://mypy.readthedocs.io/en/latest/type_narrowing.html">type
narrowing</a>.
This post describes another, less-documented way to use runtime evidence
of type information.</p>
<p>First, consider the <code>cast</code> operation in in the
<code>typing</code> module. <a href="https://docs.python.org/3/library/typing.html#typing.cast">The
docs</a> say:</p>
<blockquote>
<p><code>typing.cast(ty, val)</code></p>
<p>Cast a value to a type.</p>
<p>This returns the value unchanged. To the type checker this signals
that the return value has the designated type, but at runtime we
intentionally don't check anything (we want this to be as fast as
possible).</p>
</blockquote>
<p>In other words, it's up to the programmer to ensure that the runtime
type of the value argument really is a subtype of the type argument.
What if we could make a version of <code>cast</code>, perhaps
<code>safe_cast</code>, that makes sure that's the case? It would need
to meet two requirements:</p>
<ol>
<li>Performance: No overhead at calls to <code>safe_cast</code>, just
like <code>cast</code>. No assertions, no conditionals.</li>
<li>Safety: It should be the case that every call to
<code>safe_cast</code> is guaranteed (up to bugs in Mypy or
programmers doing something obviously tricky) to succeed.</li>
</ol>
<p>Well, there's good news! We can:</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#cd74e8;">from </span><span style="color:#abb2bf;">__future__ </span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">annotations
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">from </span><span style="color:#abb2bf;">dataclasses </span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">dataclass
</span><span style="color:#cd74e8;">from </span><span style="color:#abb2bf;">typing </span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Generic, Type, TypeVar, final
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">Sub </span><span style="color:#adb7c9;">= </span><span style="color:#eb6772;">TypeVar</span><span style="color:#abb2bf;">(</span><span style="color:#9acc76;">&quot;Sub&quot;</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">Super </span><span style="color:#adb7c9;">= </span><span style="color:#eb6772;">TypeVar</span><span style="color:#abb2bf;">(</span><span style="color:#9acc76;">&quot;Super&quot;</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">final
</span><span style="color:#cd74e8;">class </span><span style="color:#f0c678;">Subclass_</span><span style="color:#adb7c9;">(</span><span style="color:#9acc76;">Generic</span><span style="color:#adb7c9;">[Sub, Super]):
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5ebfcc;">__init__</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">, </span><span style="color:#eb6772;">sub</span><span style="color:#abb2bf;">: Type[Sub], </span><span style="color:#eb6772;">sup</span><span style="color:#abb2bf;">: Type[Super]) -&gt; </span><span style="color:#db9d63;">None</span><span style="color:#abb2bf;">:
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">assert </span><span style="color:#5ebfcc;">issubclass</span><span style="color:#abb2bf;">(sub, sup)
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">def </span><span style="color:#5cb3fa;">safe_cast</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">evidence</span><span style="color:#abb2bf;">: Subclass_[Sub, Super], </span><span style="color:#eb6772;">value</span><span style="color:#abb2bf;">: Sub) -&gt; Super:
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">return </span><span style="color:#abb2bf;">value  </span><span style="font-style:italic;color:#5f697a;"># type: ignore[return-value]
</span></code></pre>
<p>Here's what it looks like at the REPL:</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#eb6772;">Subclass_</span><span style="color:#abb2bf;">(bool, int)
</span><span style="color:#eb6772;">Subclass_</span><span style="color:#abb2bf;">()
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#eb6772;">Subclass_</span><span style="color:#abb2bf;">(bool, str)
</span><span style="color:#eb6772;">Traceback </span><span style="color:#abb2bf;">(most recent call last):
</span><span style="color:#abb2bf;">  File </span><span style="color:#9acc76;">&quot;&lt;stdin&gt;&quot;</span><span style="color:#abb2bf;">, line </span><span style="color:#db9d63;">1</span><span style="color:#abb2bf;">, </span><span style="color:#cd74e8;">in </span><span style="color:#adb7c9;">&lt;</span><span style="color:#abb2bf;">module</span><span style="color:#adb7c9;">&gt;
</span><span style="color:#abb2bf;">  File </span><span style="color:#9acc76;">&quot;/blog/reify.py&quot;</span><span style="color:#abb2bf;">, line </span><span style="color:#db9d63;">13</span><span style="color:#abb2bf;">, </span><span style="color:#cd74e8;">in </span><span style="color:#5ebfcc;">__init__
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">assert </span><span style="color:#5ebfcc;">issubclass</span><span style="color:#abb2bf;">(sub, sup)
</span><span style="color:#abb2bf;">AssertionError
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#eb6772;">safe_cast</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">Subclass_</span><span style="color:#abb2bf;">(bool, int), </span><span style="color:#db9d63;">True</span><span style="color:#abb2bf;">) </span><span style="color:#adb7c9;">+ </span><span style="color:#db9d63;">2
</span><span style="color:#db9d63;">3
</span></code></pre>
<p>So how does this work? Well, if you've got a value of type
<code>Subclass_[Sub, Super]</code> in scope, then (unless you've done something
<em>really</em> tricky) it must be the case that at some point, the assertion
written in <code>Subclass_.__init__</code> passed. This means that
<code>Sub</code> is a subclass of <code>Super</code>, and so by the
Liskov substitution principle you can use any value of type
<code>Sub</code> in a context where a <code>Super</code> is expected.</p>
<p>To understand the technique in generality, let's refine this example
and take a look at a few more.</p>
<h2 id="subclass"><code>Subclass</code></h2>
<p>For the sake of usability, let's extend the code with three additional
features:</p>
<ul>
<li>Throw a custom exception instead of using assertions</li>
<li>Add the types as fields (for reasons explained below)</li>
</ul>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">dataclass</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">frozen</span><span style="color:#adb7c9;">=</span><span style="color:#db9d63;">True</span><span style="color:#abb2bf;">)
</span><span style="color:#cd74e8;">class </span><span style="color:#f0c678;">NotASubclass</span><span style="color:#adb7c9;">(</span><span style="color:#9acc76;">Generic</span><span style="color:#adb7c9;">[Sub, Super], </span><span style="color:#9acc76;">Exception</span><span style="color:#adb7c9;">):
</span><span style="color:#abb2bf;">    sub: Type[Sub]
</span><span style="color:#abb2bf;">    sup: Type[Super]
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5ebfcc;">__str__</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">) -&gt; str:
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">return f</span><span style="color:#9acc76;">&quot;</span><span style="color:#abb2bf;">{</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.sub}</span><span style="color:#9acc76;"> is not a subclass of </span><span style="color:#abb2bf;">{</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.sup}</span><span style="color:#9acc76;">&quot;
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">final
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">dataclass
</span><span style="color:#cd74e8;">class </span><span style="color:#f0c678;">Subclass</span><span style="color:#adb7c9;">(</span><span style="color:#9acc76;">Generic</span><span style="color:#adb7c9;">[Sub, Super]):
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    sub: Type[Sub]
</span><span style="color:#abb2bf;">    sup: Type[Super]
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5ebfcc;">__init__</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">, </span><span style="color:#eb6772;">sub</span><span style="color:#abb2bf;">: Type[Sub], </span><span style="color:#eb6772;">sup</span><span style="color:#abb2bf;">: Type[Super]) -&gt; </span><span style="color:#db9d63;">None</span><span style="color:#abb2bf;">:
</span><span style="color:#abb2bf;">        </span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.sub </span><span style="color:#adb7c9;">= </span><span style="color:#abb2bf;">sub
</span><span style="color:#abb2bf;">        </span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.sup </span><span style="color:#adb7c9;">= </span><span style="color:#abb2bf;">sup
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">if not </span><span style="color:#5ebfcc;">issubclass</span><span style="color:#abb2bf;">(sub, sup):
</span><span style="color:#abb2bf;">            </span><span style="color:#cd74e8;">raise </span><span style="color:#eb6772;">NotASubclass</span><span style="color:#abb2bf;">(sub, sup)
</span></code></pre>
<p>So why add the types as fields? It's not <em>necessary</em>, but it does
extend the reach of our reasoning by enabling us to add &quot;lemmas&quot; like
this:</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#abb2bf;">T1 </span><span style="color:#adb7c9;">= </span><span style="color:#eb6772;">TypeVar</span><span style="color:#abb2bf;">(</span><span style="color:#9acc76;">&quot;T1&quot;</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">T2 </span><span style="color:#adb7c9;">= </span><span style="color:#eb6772;">TypeVar</span><span style="color:#abb2bf;">(</span><span style="color:#9acc76;">&quot;T2&quot;</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">T3 </span><span style="color:#adb7c9;">= </span><span style="color:#eb6772;">TypeVar</span><span style="color:#abb2bf;">(</span><span style="color:#9acc76;">&quot;T3&quot;</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">
</span><span style="color:#cd74e8;">def </span><span style="color:#5cb3fa;">subclass_transitive</span><span style="color:#abb2bf;">(
</span><span style="color:#abb2bf;">        </span><span style="color:#eb6772;">evidence1</span><span style="color:#abb2bf;">: Subclass[T1, T2],
</span><span style="color:#abb2bf;">        </span><span style="color:#eb6772;">evidence2</span><span style="color:#abb2bf;">: Subclass[T2, T3]) -&gt; Subclass[T1, T3]:
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">return </span><span style="color:#eb6772;">Subclass</span><span style="color:#abb2bf;">(evidence1.sub, evidence2.sup)
</span></code></pre>
<p>If you don't like the memory overhead, you can instead &quot;axiomatize&quot;
lemmas, by returning a sentinel value such as
<code>Subclass[object, object]</code> with a
<code># type: ignore[return-value]</code> comment.</p>
<h2 id="sametype"><code>SameType</code></h2>
<p>Subclassing is a partial order on types, and in particular, it's
antisymmetric. If two types are both subclasses of each other, they're
the same type:</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">final
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">dataclass
</span><span style="color:#cd74e8;">class </span><span style="color:#f0c678;">SameType</span><span style="color:#adb7c9;">(</span><span style="color:#9acc76;">Generic</span><span style="color:#adb7c9;">[T1, T2]):
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    ty: Type[T1]
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5ebfcc;">__init__</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">, </span><span style="color:#eb6772;">evidence1</span><span style="color:#abb2bf;">: Subclass[T1, T2],
</span><span style="color:#abb2bf;">                 </span><span style="color:#eb6772;">evidence2</span><span style="color:#abb2bf;">: Subclass[T2, T1]) -&gt; </span><span style="color:#db9d63;">None</span><span style="color:#abb2bf;">:
</span><span style="color:#abb2bf;">        </span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.ty </span><span style="color:#adb7c9;">= </span><span style="color:#abb2bf;">evidence1.sub
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="font-style:italic;color:#5f697a;"># These would be necessary for writing any lemmas:
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5cb3fa;">get1</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">) -&gt; Type[T1]:
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">return </span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.ty
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5cb3fa;">get2</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">) -&gt; Type[T2]:
</span><span style="color:#abb2bf;">        </span><span style="font-style:italic;color:#5f697a;"># Could also save the evidence and use safe_cast here
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">return </span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.ty  </span><span style="font-style:italic;color:#5f697a;"># type: ignore[return-value]
</span><span style="color:#abb2bf;">
</span></code></pre>
<p>Here, we don't need a custom exception type nor any assertion in the
constructor, since both of these are &quot;inherited&quot; from
<code>Subclass</code>.</p>
<p>Some ideas for lemmas:</p>
<ul>
<li><code>SameType[T1, T2]</code> implies <code>Subclass[T1, T2]</code></li>
<li><code>SameType</code> is symmetric</li>
<li><code>SameType</code> is transitive</li>
</ul>
<h2 id="intuple"><code>InTuple</code></h2>
<p>Now for something a bit more involved. Recall <a href="https://www.python.org/dev/peps/pep-0585">PEP 585: Type Hinting
Generics In Standard
Collections</a>. This PEP
obviates <code>typing.Dict</code>, <code>typing.List</code>,
<code>typing.Tuple</code>, and more by allowing us to write the
corresponding types directly inside type signatures:python```python
def repeat(i: int, n: int) -&gt; list[int]:
pass</p>
<h1 id="old-style-equivalent">Old style (equivalent):</h1>
<p>from typing import List</p>
<p>def repeat_old(i: int, n: int) -&gt; List[int]:
pass</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">Crucially, types like `dict[int, str]` are also values:
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">``` python
</span><span style="color:#abb2bf;">&gt;&gt;&gt; dict[int, str]
</span><span style="color:#abb2bf;">dict[int, str]
</span></code></pre>
<p>Moreover, their type arguments <a href="https://www.python.org/dev/peps/pep-0585/#parameters-to-generics-are-available-at-runtime">are available at
runtime</a>:</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#abb2bf;">dict[int, str].__args__
</span><span style="color:#abb2bf;">(</span><span style="color:#adb7c9;">&lt;</span><span style="background-color:#e05252;color:#ffffff;">class</span><span style="color:#abb2bf;"> </span><span style="color:#9acc76;">&#39;int&#39;</span><span style="color:#adb7c9;">&gt;</span><span style="color:#abb2bf;">, </span><span style="color:#adb7c9;">&lt;</span><span style="background-color:#e05252;color:#ffffff;">class</span><span style="color:#abb2bf;"> </span><span style="color:#9acc76;">&#39;str&#39;</span><span style="color:#adb7c9;">&gt;</span><span style="background-color:#e05252;color:#ffffff;">)</span><span style="color:#abb2bf;">
</span></code></pre>
<p>So what can we do with this? Here's a generic class
<code>InTuple[T, Tup]</code>. It has two type parameters, the second of
which is bounded above by <code>Tuple[Any, ...]</code>. If you can
construct one, it means that the type <code>T</code> is one of the types
in the tuple type <code>Tup</code>.</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#cd74e8;">from </span><span style="color:#abb2bf;">typing </span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Any, Tuple
</span><span style="color:#abb2bf;">
</span><span style="font-style:italic;color:#5f697a;"># For some reason, tuple[Any, ...] doesn&#39;t work here, even though it is valid as
</span><span style="font-style:italic;color:#5f697a;"># a value at the REPL.
</span><span style="color:#abb2bf;">Tup </span><span style="color:#adb7c9;">= </span><span style="color:#eb6772;">TypeVar</span><span style="color:#abb2bf;">(</span><span style="color:#9acc76;">&quot;Tup&quot;</span><span style="color:#abb2bf;">, </span><span style="color:#eb6772;">bound</span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;">Tuple[Any, </span><span style="color:#db9d63;">...</span><span style="color:#abb2bf;">])
</span><span style="color:#abb2bf;">T </span><span style="color:#adb7c9;">= </span><span style="color:#eb6772;">TypeVar</span><span style="color:#abb2bf;">(</span><span style="color:#9acc76;">&quot;T&quot;</span><span style="color:#abb2bf;">)
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">dataclass</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">frozen</span><span style="color:#adb7c9;">=</span><span style="color:#db9d63;">True</span><span style="color:#abb2bf;">)
</span><span style="color:#cd74e8;">class </span><span style="color:#f0c678;">NotInTuple</span><span style="color:#adb7c9;">(</span><span style="color:#9acc76;">Generic</span><span style="color:#adb7c9;">[T, Tup], </span><span style="color:#9acc76;">Exception</span><span style="color:#adb7c9;">):
</span><span style="color:#abb2bf;">    ty: Type[T]
</span><span style="color:#abb2bf;">    tup: Type[Tup]
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5ebfcc;">__str__</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">) -&gt; str:
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">return f</span><span style="color:#9acc76;">&quot;Type </span><span style="color:#abb2bf;">{</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.ty}</span><span style="color:#9acc76;"> is not in tuple type </span><span style="color:#abb2bf;">{</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.tup}</span><span style="color:#9acc76;">&quot;
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">final
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">dataclass
</span><span style="color:#cd74e8;">class </span><span style="color:#f0c678;">InTuple</span><span style="color:#adb7c9;">(</span><span style="color:#9acc76;">Generic</span><span style="color:#adb7c9;">[T, Tup]):
</span><span style="color:#abb2bf;">    </span><span style="font-style:italic;color:#5f697a;">&quot;&quot;&quot;Witness that ``T`` is in ``Tup``.&quot;&quot;&quot;
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    ty: Type[T]
</span><span style="color:#abb2bf;">    tup: Type[Tup]
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5ebfcc;">__init__</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">, </span><span style="color:#eb6772;">ty</span><span style="color:#abb2bf;">: Type[T], </span><span style="color:#eb6772;">tup</span><span style="color:#abb2bf;">: Type[Tup]) -&gt; </span><span style="color:#db9d63;">None</span><span style="color:#abb2bf;">:
</span><span style="color:#abb2bf;">        </span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.ty </span><span style="color:#adb7c9;">= </span><span style="color:#abb2bf;">ty
</span><span style="color:#abb2bf;">        </span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.tup </span><span style="color:#adb7c9;">= </span><span style="color:#abb2bf;">tup
</span><span style="color:#abb2bf;">        </span><span style="font-style:italic;color:#5f697a;"># Mypy version 0.910 doesn&#39;t acknowledge that this attribute is defined,
</span><span style="color:#abb2bf;">        </span><span style="font-style:italic;color:#5f697a;"># but it is.
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">for </span><span style="color:#abb2bf;">tup_ty </span><span style="color:#cd74e8;">in </span><span style="color:#abb2bf;">tup.__args__:  </span><span style="font-style:italic;color:#5f697a;"># type: ignore[attr-defined]
</span><span style="color:#abb2bf;">            </span><span style="color:#cd74e8;">if </span><span style="color:#abb2bf;">ty </span><span style="color:#adb7c9;">== </span><span style="color:#abb2bf;">tup_ty:
</span><span style="color:#abb2bf;">                </span><span style="color:#cd74e8;">return
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">raise </span><span style="color:#eb6772;">NotInTuple</span><span style="color:#abb2bf;">(ty, tup)
</span></code></pre>
<p>Let's try it out:</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#eb6772;">InTuple</span><span style="color:#abb2bf;">(int, tuple[int, str])
</span><span style="color:#eb6772;">InTuple</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">ty</span><span style="color:#adb7c9;">=&lt;</span><span style="background-color:#e05252;color:#ffffff;">class</span><span style="color:#abb2bf;"> </span><span style="color:#9acc76;">&#39;int&#39;</span><span style="color:#adb7c9;">&gt;</span><span style="color:#abb2bf;">, </span><span style="color:#eb6772;">tup</span><span style="color:#adb7c9;">=</span><span style="color:#abb2bf;">tuple[int, str])
</span><span style="color:#abb2bf;">
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#eb6772;">InTuple</span><span style="color:#abb2bf;">(int, tuple[str, list[str], bool])
</span><span style="color:#eb6772;">Traceback </span><span style="color:#abb2bf;">(most recent call last):
</span><span style="color:#abb2bf;">  File </span><span style="color:#9acc76;">&quot;&lt;stdin&gt;&quot;</span><span style="color:#abb2bf;">, line </span><span style="color:#db9d63;">1</span><span style="color:#abb2bf;">, </span><span style="color:#cd74e8;">in </span><span style="color:#adb7c9;">&lt;</span><span style="color:#abb2bf;">module</span><span style="color:#adb7c9;">&gt;
</span><span style="color:#abb2bf;">  File </span><span style="color:#9acc76;">&quot;/blog/reify.py&quot;</span><span style="color:#abb2bf;">, line </span><span style="color:#db9d63;">44</span><span style="color:#abb2bf;">, </span><span style="color:#cd74e8;">in </span><span style="color:#5ebfcc;">__init__
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">raise </span><span style="color:#eb6772;">NotInTuple</span><span style="color:#abb2bf;">(ty, tup)
</span><span style="color:#abb2bf;">__main__.NotIn: Type </span><span style="color:#adb7c9;">&lt;</span><span style="background-color:#e05252;color:#ffffff;">class</span><span style="color:#abb2bf;"> </span><span style="color:#9acc76;">&#39;int&#39;</span><span style="color:#adb7c9;">&gt; </span><span style="color:#cd74e8;">is not in </span><span style="color:#abb2bf;">tuple </span><span style="color:#5ebfcc;">type </span><span style="color:#abb2bf;">tuple[str, list[str], bool]
</span></code></pre>
<p>So what can we do with this? Well, probably lots of things! We can write
a function that gets the first value of a given type out of a tuple,
regardless of its index:python```python
def first(evidence: InTuple[T, Tup], tup: Tup) -&gt; T:
for elem in tup:
if isinstance(elem, evidence.ty):
return elem
assert False, f&quot;Impossible: Bad 'InTuple' value {evidence=} {tup=}&quot;</p>
<pre style="background-color:#2b303b;color:#6c7079;"><code><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">``` python
</span><span style="color:#abb2bf;">&gt;&gt;&gt; first(InTuple(int, tuple[str, int, bool, int]), (&quot;string&quot;, 5, False, 10))
</span><span style="color:#abb2bf;">5
</span></code></pre>
<p>This isn't so impressive when we construct a literal
<code>InTuple</code> value as the first argument, but might be helpful
in more polymorphic scenarios.</p>
<p>It's also worth noting that this function can be a bit unintuitive when
combined with certain subclass relationships:</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#5ebfcc;">issubclass</span><span style="color:#abb2bf;">(bool, int)
</span><span style="color:#db9d63;">True
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#eb6772;">first</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">InTuple</span><span style="color:#abb2bf;">(int, tuple[bool, int, str, int]), (</span><span style="color:#db9d63;">False</span><span style="color:#abb2bf;">, </span><span style="color:#db9d63;">5</span><span style="color:#abb2bf;">, </span><span style="color:#9acc76;">&quot;string&quot;</span><span style="color:#abb2bf;">, </span><span style="color:#db9d63;">10</span><span style="color:#abb2bf;">))
</span><span style="color:#db9d63;">False
</span></code></pre>
<p>It's worth noting that any of these predicates or relationships could
be negated, simply by inverting the conditional and renaming the class.
You could probably have a lemma that the negation of
<code>InTuple</code> is reflexive, but I can't think of how you'd use
it.</p>
<h2 id="isgenericargument"><code>IsGenericArgument</code></h2>
<p>In fact, parameters to <em>all</em> generic types are available at runtime:</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#cd74e8;">from </span><span style="color:#abb2bf;">typing </span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Mapping, Generic, TypeVar
</span><span style="color:#abb2bf;">
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#abb2bf;">Mapping[int, str].__args__
</span><span style="color:#abb2bf;">(</span><span style="color:#adb7c9;">&lt;</span><span style="background-color:#e05252;color:#ffffff;">class</span><span style="color:#abb2bf;"> </span><span style="color:#9acc76;">&#39;int&#39;</span><span style="color:#adb7c9;">&gt;</span><span style="color:#abb2bf;">, </span><span style="color:#adb7c9;">&lt;</span><span style="background-color:#e05252;color:#ffffff;">class</span><span style="color:#abb2bf;"> </span><span style="color:#9acc76;">&#39;str&#39;</span><span style="color:#adb7c9;">&gt;</span><span style="background-color:#e05252;color:#ffffff;">)</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#abb2bf;">T </span><span style="color:#adb7c9;">= </span><span style="color:#eb6772;">TypeVar</span><span style="color:#abb2bf;">(</span><span style="color:#9acc76;">&quot;T&quot;</span><span style="color:#abb2bf;">)
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="background-color:#e05252;color:#ffffff;">class</span><span style="color:#abb2bf;"> </span><span style="color:#eb6772;">G</span><span style="color:#abb2bf;">(Generic[T]):
</span><span style="color:#db9d63;">...     </span><span style="color:#cd74e8;">pass
</span><span style="color:#db9d63;">...
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#abb2bf;">G[int].__args__
</span><span style="color:#abb2bf;">(</span><span style="color:#adb7c9;">&lt;</span><span style="background-color:#e05252;color:#ffffff;">class</span><span style="color:#abb2bf;"> </span><span style="color:#9acc76;">&#39;int&#39;</span><span style="color:#adb7c9;">&gt;</span><span style="color:#abb2bf;">,</span><span style="background-color:#e05252;color:#ffffff;">)</span><span style="color:#abb2bf;">
</span></code></pre>
<p>So we can handily generalize the previous example just by creating a new
exception type, replacing the <code>Tup</code> variable with something
unconstrained, and renaming the class to <code>IsGenericArgument</code>.</p>
<h2 id="newtypeof"><code>NewtypeOf</code></h2>
<p>How can we tell if a given type is just a <code>NewType</code> wrapper
around another one? Well, let's investigate:</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#cd74e8;">from </span><span style="color:#abb2bf;">typing </span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">NewType
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#abb2bf;">Pos </span><span style="color:#adb7c9;">= </span><span style="color:#eb6772;">NewType</span><span style="color:#abb2bf;">(</span><span style="color:#9acc76;">&quot;Pos&quot;</span><span style="color:#abb2bf;">, int)
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#abb2bf;">Pos
</span><span style="color:#adb7c9;">&lt;</span><span style="color:#abb2bf;">function NewType.</span><span style="color:#adb7c9;">&lt;</span><span style="color:#5ebfcc;">locals</span><span style="color:#adb7c9;">&gt;</span><span style="color:#abb2bf;">.new_type at </span><span style="color:#db9d63;">0x7fa08729b4c0</span><span style="color:#adb7c9;">&gt;
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#5ebfcc;">dir</span><span style="color:#abb2bf;">(Pos)
</span><span style="color:#abb2bf;">[</span><span style="color:#db9d63;">...</span><span style="color:#abb2bf;">, </span><span style="color:#9acc76;">&#39;__supertype__&#39;</span><span style="color:#abb2bf;">]
</span><span style="color:#adb7c9;">&gt;&gt;&gt; </span><span style="color:#abb2bf;">Pos.__supertype__
</span><span style="color:#adb7c9;">&lt;</span><span style="background-color:#e05252;color:#ffffff;">class</span><span style="color:#abb2bf;"> </span><span style="color:#9acc76;">&#39;int&#39;</span><span style="color:#adb7c9;">&gt;
</span></code></pre>
<p>Ah, that's <em>just</em> what we need!</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#cd74e8;">from </span><span style="color:#abb2bf;">typing </span><span style="color:#cd74e8;">import </span><span style="color:#abb2bf;">Callable
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">dataclass</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">frozen</span><span style="color:#adb7c9;">=</span><span style="color:#db9d63;">True</span><span style="color:#abb2bf;">)
</span><span style="color:#cd74e8;">class </span><span style="color:#f0c678;">NotANewtypeOf</span><span style="color:#adb7c9;">(</span><span style="color:#9acc76;">Generic</span><span style="color:#adb7c9;">[Sub, Super], </span><span style="color:#9acc76;">Exception</span><span style="color:#adb7c9;">):
</span><span style="color:#abb2bf;">    sub: Callable[[Super], Sub]
</span><span style="color:#abb2bf;">    sup: Type[Super]
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5ebfcc;">__str__</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">) -&gt; str:
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">return f</span><span style="color:#9acc76;">&#39;</span><span style="color:#abb2bf;">{</span><span style="color:#5ebfcc;">getattr</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.sub, </span><span style="color:#9acc76;">&quot;__name__&quot;</span><span style="color:#abb2bf;">, </span><span style="color:#9acc76;">&quot;&lt;unknown&gt;&quot;</span><span style="color:#abb2bf;">)}</span><span style="color:#9acc76;"> is not a newtype of </span><span style="color:#abb2bf;">{</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.sup}</span><span style="color:#9acc76;">&#39;
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">final
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">dataclass
</span><span style="color:#cd74e8;">class </span><span style="color:#f0c678;">NewtypeOf</span><span style="color:#adb7c9;">(</span><span style="color:#9acc76;">Generic</span><span style="color:#adb7c9;">[Sub, Super]):
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    sub: Callable[[Super], Sub]
</span><span style="color:#abb2bf;">    sup: Type[Super]
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5ebfcc;">__init__</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">, </span><span style="color:#eb6772;">sub</span><span style="color:#abb2bf;">: Callable[[Super], Sub], </span><span style="color:#eb6772;">sup</span><span style="color:#abb2bf;">: Type[Super]) -&gt; </span><span style="color:#db9d63;">None</span><span style="color:#abb2bf;">:
</span><span style="color:#abb2bf;">        </span><span style="font-style:italic;color:#5f697a;"># Mypy has trouble with Callable fields...
</span><span style="color:#abb2bf;">        </span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.sub </span><span style="color:#adb7c9;">= </span><span style="color:#abb2bf;">sub  </span><span style="font-style:italic;color:#5f697a;"># type: ignore[assignment]
</span><span style="color:#abb2bf;">        </span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.sup </span><span style="color:#adb7c9;">= </span><span style="color:#abb2bf;">sup
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">if not </span><span style="color:#5ebfcc;">getattr</span><span style="color:#abb2bf;">(sub, </span><span style="color:#9acc76;">&quot;__supertype__&quot;</span><span style="color:#abb2bf;">) </span><span style="color:#adb7c9;">== </span><span style="color:#abb2bf;">sup:
</span><span style="color:#abb2bf;">            </span><span style="color:#cd74e8;">raise </span><span style="color:#eb6772;">NotANewtypeOf</span><span style="color:#abb2bf;">(sub, sup)
</span></code></pre>
<p>Some ideas for lemmas:</p>
<ul>
<li>Is this transitive?</li>
<li><code>NewtypeOf</code> implies <code>Subtype</code></li>
</ul>
<h2 id="newtype"><code>Newtype</code></h2>
<p>The above example also leads naturally to our first <em>predicate</em> or
<em>property</em> of interest on types, rather than a <em>relationship between</em>
types, namely, whether or not a given type is in fact a
<code>NewType</code>.</p>
<pre data-lang="python" style="background-color:#2b303b;color:#6c7079;" class="language-python "><code class="language-python" data-lang="python"><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">dataclass</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">frozen</span><span style="color:#adb7c9;">=</span><span style="color:#db9d63;">True</span><span style="color:#abb2bf;">)
</span><span style="color:#cd74e8;">class </span><span style="color:#f0c678;">NotANewtype</span><span style="color:#adb7c9;">(</span><span style="color:#9acc76;">Generic</span><span style="color:#adb7c9;">[Sub, Super], </span><span style="color:#9acc76;">Exception</span><span style="color:#adb7c9;">):
</span><span style="color:#abb2bf;">    sub: Callable[[Super], Sub]
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5ebfcc;">__str__</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">) -&gt; str:
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">return f</span><span style="color:#9acc76;">&#39;</span><span style="color:#abb2bf;">{</span><span style="color:#5ebfcc;">getattr</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.sub, </span><span style="color:#9acc76;">&quot;__name__&quot;</span><span style="color:#abb2bf;">, </span><span style="color:#9acc76;">&quot;&lt;unknown&gt;&quot;</span><span style="color:#abb2bf;">)}</span><span style="color:#9acc76;"> is not a newtype&#39;
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">final
</span><span style="color:#abb2bf;">@</span><span style="color:#eb6772;">dataclass
</span><span style="color:#cd74e8;">class </span><span style="color:#f0c678;">Newtype</span><span style="color:#adb7c9;">(</span><span style="color:#9acc76;">Generic</span><span style="color:#adb7c9;">[Sub, Super]):
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    sub: Callable[[Super], Sub]
</span><span style="color:#abb2bf;">
</span><span style="color:#abb2bf;">    </span><span style="color:#cd74e8;">def </span><span style="color:#5ebfcc;">__init__</span><span style="color:#abb2bf;">(</span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">, </span><span style="color:#eb6772;">sub</span><span style="color:#abb2bf;">: Callable[[Super], Sub]) -&gt; </span><span style="color:#db9d63;">None</span><span style="color:#abb2bf;">:
</span><span style="color:#abb2bf;">        </span><span style="color:#eb6772;">self</span><span style="color:#abb2bf;">.sub </span><span style="color:#adb7c9;">= </span><span style="color:#abb2bf;">sub  </span><span style="font-style:italic;color:#5f697a;"># type: ignore[assignment]
</span><span style="color:#abb2bf;">        </span><span style="color:#cd74e8;">if </span><span style="color:#5ebfcc;">getattr</span><span style="color:#abb2bf;">(sub, </span><span style="color:#9acc76;">&quot;__supertype__&quot;</span><span style="color:#abb2bf;">) </span><span style="color:#cd74e8;">is </span><span style="color:#db9d63;">None</span><span style="color:#abb2bf;">:
</span><span style="color:#abb2bf;">            </span><span style="color:#cd74e8;">raise </span><span style="color:#eb6772;">NotANewtype</span><span style="color:#abb2bf;">(sub)
</span></code></pre>
<h2 id="more-ideas">More Ideas</h2>
<p>What other predicates on and relations between types do we care about? A
few ideas:</p>
<ul>
<li>
<p><code>Subclassable</code>: Some types aren't! For example,
<code>&lt;class 'function'&gt;</code> (try <code>type(lambda: None)</code>
in the REPL).</p>
</li>
<li>
<p><code>IsAbstract</code>, or <code>NotAbstract</code>: I don't know
if it's possible to check this at runtime, but it would be cool if
it were!</p>
</li>
<li>
<p><code>HasMetaclass</code>: Check that a class has a given metaclass.</p>
</li>
</ul>
<p>Do you have other ideas or use-cases? Drop me a line!</p>

  </div>
</body>
</html>
