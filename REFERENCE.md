# Function Listing For SERAPEUM (31 files, 309 functions)

- [Macro Tools](#macro-tools)
- [Types](#types)
- [Definitions](#definitions)
- [Binding](#binding)
- [Control Flow](#control-flow)
- [Threads](#threads)
- [Iter](#iter)
- [Conditions](#conditions)
- [Op](#op)
- [Functions](#functions)
- [Trees](#trees)
- [Hash Tables](#hash-tables)
- [Files](#files)
- [Symbols](#symbols)
- [Arrays](#arrays)
- [Queue](#queue)
- [Box](#box)
- [Numbers](#numbers)
- [Octets](#octets)
- [Time](#time)
- [Clos](#clos)
- [Hooks](#hooks)
- [Fbind](#fbind)
- [Lists](#lists)
- [Sequences](#sequences)
- [Strings](#strings)
- [Vectors](#vectors)
- [Internal Definitions](#internal-definitions)
- [Tree Case](#tree-case)
- [Dispatch Case](#dispatch-case)
- [Range](#range)

## Macro Tools

### `(string-gensym x)`

Equivalent to (gensym (string x)).

Generally preferable to calling GENSYM with a string, because it
respects the current read table.

The alternative to writing `(mapcar (compose #'gensym #'string) ...)'
in every other macro.

[View source](macro-tools.lisp#L50)

### `(unique-name x)`

Alias for `string-gensym`.

[View source](macro-tools.lisp#L62)

### `(unsplice form)`

If FORM is non-nil, wrap it in a list.

This is useful with ,@ in macros, and with `mapcan`.

E.g., instead of writing:

    `(.... ,@(when flag '((code))))

You can write:

    `(.... ,@(unsplice (when flag '(code))))

From Lparallel.

[View source](macro-tools.lisp#L74)

### `(with-thunk (var &rest args) &body body)`

A macro-writing macro for the `call-with-` style.

In the `call-with-` style of writing macros, the macro is simply a
syntactic convenience that wraps its body in a thunk and a call to the
function that does the actual work.

    (defmacro with-foo (&body body)
      `(call-with-foo (lambda () ,@body)))

The `call-with-` style has many advantages. Functions are easier to
write than macros; you can change the behavior of a function without
having to recompile all its callers; functions can be traced, appear
in backtraces, etc.

But meanwhile, all those thunks are being allocated on the heap. Can
we avoid this? Yes, but at a high cost in boilerplate: the closure has
to be given a name (using `flet`) so it can be declared
`dynamic-extent`.

    (defmacro with-foo (&body body)
      (with-gensyms (thunk)
        `(flet ((,thunk () ,@body))
           (declare (dynamic-extent #',thunk))
           (call-with-foo #',thunk))))

`with-thunk` avoids the boilerplate:

    (defmacro with-foo (&body body)
      (with-thunk (body)
        `(call-with-foo ,body)))

It is also possible to construct a "thunk" with arguments.

    (with-thunk (body foo)
      `(call-with-foo ,body))
    ≡ `(flet ((,thunk (,foo)
          ,@body))
        (declare (dynamic-extent #',thunk))
        (call-with-foo #',thunk))

Someday this may have a better name.

[View source](macro-tools.lisp#L95)

### `(expand-macro form &optional env)`

Like `macroexpand-1`, but also expand compiler macros.
From Swank.

[View source](macro-tools.lisp#L151)

### `(expand-macro-recursively form &optional env)`

Like `macroexpand`, but also expand compiler macros.
From Swank.

[View source](macro-tools.lisp#L160)

### `(partition-declarations xs declarations &optional env)`

Split DECLARATIONS into those that do and do not apply to XS.
Return two values, one with each set.

Both sets of declarations are returned in a form that can be spliced
directly into Lisp code:

     (locally ,@(partition-declarations vars decls) ...)

[View source](macro-tools.lisp#L173)

### `(callf function place &rest args)`

Set PLACE to the value of calling FUNCTION on PLACE, with ARGS.

[View source](macro-tools.lisp#L259)

### `(callf2 function arg1 place &rest args)`

Like CALLF, but with the place as the second argument.

[View source](macro-tools.lisp#L268)

### `(define-do-macro name binds &body body)`

Define an iteration macro like `dolist`.

Writing a macro like `dolist` is more complicated than it looks. For
consistency with the rest of CL, you have to do all of the following:

- The entire loop must be surrounded with an implicit `nil` block.
- The body of the loop must be an implicit `tagbody`.
- There must be an optional `return` form which, if given, supplies
  the values to return from the loop.
- While this return form is being evaluated, the iteration variables
  must be bound to `nil`.

Say you wanted to define a `do-hash` macro that iterates over hash
tables. A full implementation would look like this:

     (defmacro do-hash ((key value hash-table &optional return) &body body)
       (multiple-value-bind (body decls) (parse-body body)
         `(block nil
            (maphash (lambda (,key ,value)
                       ,@decls
                       (tagbody
                          ,@body))
                     ,hash-table)
            ,(when return
               `(let (,key ,value)
                  ,return)))))

Using `define-do-macro` takes care of all of this for you.

     (define-do-macro do-hash ((key value hash-table &optional return) &body body)
       `(maphash (lambda (,key ,value)
                   ,@body)
                 ,hash-table))

[View source](macro-tools.lisp#L277)

### `(define-post-modify-macro name lambda-list function &optional documentation)`

Like `define-modify-macro`, but arranges to return the original value.

[View source](macro-tools.lisp#L338)

### `(define-case-macro name macro-args params &body macro-body)`

Define a macro like `case`.

A case-like macro is one that supports the following syntax:

- A list of keys is treated as matching any key in the list.
- An empty list matches nothing.
- The atoms T or `otherwise` introduce a default clause.
- There can only be one default clause.
- The default clause must come last.
- Any atom besides the empty list, T, or `otherwise` matches itself.

As a consequence of the above, to match against the empty list, T, or
`otherwise`, they must be wrapped in a list.

    (case x
      ((nil) "Matched nil.")
      ((t) "Matched t.")
      ((otherwise) "Matched `otherwise`.")
      (otherwise "Didn't match anything."))

A macro defined using `define-case-macro` can ignore all of the above.
It receives three arguments: the expression, already protected against
multiple evaluation; a normalized list of clauses; and, optionally, a
default clause.

The clauses are normalized as a list of `(key . body)', where each key
is an atom. (That includes nil, T, and `otherwise`.) Nonetheless, each
body passed to the macro will only appear once in the expansion; there
will be no duplicated code.

The body of the default clause is passed separately,
bound to the value of the `:default` keyword in PARAMS.

    (define-case-macro my-case (expr &body clauses)
        (:default default)
      ....)

Note that in this case, `default` will be bound to the clause's body
-- a list of forms -- and not to the whole clause. The key of the
default clause is discarded.

If no binding is specified for the default clause, then no default
clause is allowed.

One thing you do still have to consider is the handling of duplicated
keys. The macro defined by `define-case-macro` will reject case sets
that contains duplicate keys under `eql`, but depending on the
semantics of your macro, you may need to check for duplicates under a
looser definition of equality.

As a final example, if the `case` macro did not already exist, you
could define it almost trivially using `define-case-macro`:

    (define-case-macro my-case (expr &body clause)
        (:default default)
      `(cond
         ,@(loop for (key . body) in clauses
                 collect `((eql ,expr ,key) ,@body))
         (t ,@body)))

[View source](macro-tools.lisp#L424)

### `(case-failure expr keys)`

Signal an error of type `case-failure`.

[View source](macro-tools.lisp#L653)

### `(eval-if-constant form &optional env)`

Try to reduce FORM to a constant, using ENV.
If FORM cannot be reduced, return it unaltered.

Also return a second value, T if the form was reduced, or nil
otherwise.

This is equivalent to testing if FORM is constant, then evaluting it,
except that FORM is macro-expanded in ENV (taking compiler macros into
account) before doing the test.

[View source](macro-tools.lisp#L674)

## Types

### `(-> function args values)`

Declaim the ftype of FUNCTION from ARGS to VALUES.

     (-> mod-fixnum+ (fixnum fixnum) fixnum)
     (defun mod-fixnum+ (x y) ...)

[View source](types.lisp#L33)

### `(assure type-spec &body (form))`

Macro for inline type checking.

`assure` is to `the` as `check-type` is to `declare`.

     (the string 1)    => undefined
     (assure string 1) => error

The value returned from the `assure` form is guaranteed to satisfy
TYPE-SPEC. If FORM does not return a value of that type, then a
correctable error is signaled. You can supply a value of the correct
type with the `use-value` restart.

Note that the supplied value is *not* saved into the place designated
by FORM. (But see `assuref`.)

From ISLISP.

[View source](types.lisp#L131)

### `(assuref place type-spec)`

Like `(progn (check-type PLACE TYPE-SPEC) PLACE)`, but evaluates
PLACE only once.

[View source](types.lisp#L168)

### `(supertypep supertype type &optional env)`

Is SUPERTYPE a supertype of TYPE?
That is, is TYPE a subtype of SUPERTYPE?

[View source](types.lisp#L200)

### `(proper-subtype-p subtype type &optional env)`

Is SUBTYPE a proper subtype of TYPE?

This is, is it true that SUBTYPE is a subtype of TYPE, but not the same type?

[View source](types.lisp#L206)

### `(proper-supertype-p supertype type &optional env)`

Is SUPERTYPE a proper supertype of TYPE?

That is, is it true that every value of TYPE is also of type
SUPERTYPE, but not every value of SUPERTYPE is of type TYPE?

[View source](types.lisp#L230)

### `(vref vec index)`

When used globally, same as `aref`.

Inside of a with-type-dispatch form, calls to `vref` may be bound to
different accessors, such as `char` or `schar`, or `bit` or `sbit`,
depending on the type being specialized on.

[View source](types.lisp#L282)

### `(with-type-dispatch (&rest types) var &body body)`

A macro for writing fast sequence functions (among other things).

In the simplest case, this macro produces one copy of BODY for each
type in TYPES, with the appropriate declarations to induce your Lisp
to optimize that version of BODY for the appropriate type.

Say VAR is a string. With this macro, you can trivially emit optimized
code for the different kinds of string that VAR might be. And
then (ideally) instead of getting code that dispatches on the type of
VAR every time you call `aref`, you get code that dispatches on the
type of VAR once, and then uses the appropriately specialized
accessors. (But see `with-string-dispatch`.)

But that's the simplest case. Using `with-type-dispatch` also provides
*transparent portability*. It examines TYPES to deduplicate types that
are not distinct on the current Lisp, or that are shadowed by other
provided types. And the expansion strategy may differ from Lisp to
Lisp: ideally, you should not have to pay for good performance on
Lisps with type inference with pointless code bloat on other Lisps.

There is an additional benefit for vector types. Around each version
of BODY, the definition of `vref` is shadowed to expand into an
appropriate accessor. E.g., within a version of BODY where VAR is
known to be a `simple-string`, `vref` expands into `schar`.

Using `vref` instead of `aref` is obviously useful on Lisps that do
not do type inference, but even on Lisps with type inference it can
speed compilation times (compiling `aref` is relatively slow on SBCL).

Within `with-type-dispatch`, VAR should be regarded as read-only.

Note that `with-type-dispatch` is intended to be used around
relatively expensive code, particularly loops. For simpler code, the
gains from specialized compilation may not justify the overhead of the
initial dispatch and the increased code size.

Note also that `with-type-dispatch` is relatively low level. You may
want to use one of the other macros in the same family, such as
`with-subtype-dispatch`, `with-string-dispatch`, or so forth.

The design and implementation of `with-type-dispatch` is based on a
few sources. It replaces a similar macro formerly included in
Serapeum, `with-templated-body`. One possible expansion is based on
the `string-dispatch` macro used internally in SBCL. But most of the
credit should go to the paper "Fast, Maintable, and Portable Sequence
Functions", by Irène Durand and Robert Strandh.

[View source](types.lisp#L336)

### `(with-subtype-dispatch type (&rest subtypes) var &body body)`

Like `with-type-dispatch`, but SUBTYPES must be subtypes of TYPE.

Furthermore, if SUBTYPES are not exhaustive, an extra clause will be
added to ensure that TYPE itself is handled.

[View source](types.lisp#L419)

### `(with-string-dispatch (&rest types) var &body body)`

Like `with-subtype-dispatch` with an overall type of `string`.

[View source](types.lisp#L432)

### `(with-vector-dispatch (&rest types) var &body body)`

Like `with-subtype-dispatch` with an overall type of `vector`.

[View source](types.lisp#L442)

### `(true x)`

Coerce X to a boolean.
That is, if X is null, return `nil`; otherwise return `t`.

Based on an idea by Eric Naggum.

[View source](types.lisp#L493)

## Definitions

### `(def var &body (&optional val documentation))`

The famous "deflex".

Define a top level (global) lexical VAR with initial value VAL,
which is assigned unconditionally as with DEFPARAMETER. If a DOC
string is provided, it is attached to both the name |VAR| and the name
*STORAGE-FOR-DEFLEX-VAR-|VAR|* as a documentation string of kind
'VARIABLE. The new VAR will have lexical scope and thus may be
shadowed by LET bindings without affecting its dynamic (global) value.

The original `deflex` is due to Rob Warnock.

This version of `deflex` differs from the original in the following ways:

- It is possible for VAL to close over VAR.
- On implementations that support it (SBCL, CCL, and LispWorks, at the
moment) this version creates a backing variable that is "global" or
"static", so there is not just a change in semantics, but also a
gain in efficiency.
- If VAR is a list that starts with `values`, each element is treated as
a separate variable and initialized as if by `(setf (values VAR...)
VAL)`.

[View source](definitions.lisp#L9)

### `(define-values values &body (expr))`

Like `def`, but for multiple values.
Each variable in VALUES is given a global, lexical binding, as with
`def`, then set all at once, as with `multiple-value-setq`.

[View source](definitions.lisp#L66)

### `(defconst symbol init &optional docstring)`

Define a constant, lexically.

`defconst` defines a constant using a strategy similar to `def`, so
you don’t have to +cage+ your constants.

The constant is only redefined on re-evaluation if INIT has a
different literal representation than the old value.

The name is from Emacs Lisp.

[View source](definitions.lisp#L90)

### `(defsubst name params &body body)`

Define an inline function.

     (defsubst fn ...)
     ≡ (declaim (inline fn))
       (defun fn ...)

The advantage of a separate defining form for inline functions is that
you can't forget to declaim the function inline before defining it –
without which it may not actually end up being inlined.

From Emacs and other ancient Lisps.

[View source](definitions.lisp#L114)

### `(defalias alias &body (def &optional docstring))`

Define a value as a top-level function.

     (defalias string-gensym (compose #'gensym #'string))

Like (setf (fdefinition ALIAS) DEF), but with a place to put
documentation and some niceties to placate the compiler.

Name from Emacs Lisp.

[View source](definitions.lisp#L136)

### `(defplace name args &body (form &optional docstring))`

Define NAME and (SETF NAME) in one go.

Note that the body must be a single, setf-able expression.

[View source](definitions.lisp#L178)

### `(defcondition name supers &body (slots &rest options))`

Alias for `define-condition`.

Like (define-condition ...), but blissfully conforming to the same
nomenclatural convention as every other definition form in Common
Lisp.

[View source](definitions.lisp#L190)

### `(defstruct-read-only name-and-opts &body slots)`

Easily define a defstruct with no mutable slots.

The syntax of `defstruct-read-only` is as close as possible to that of
`defstruct`. Given an existing structure definition, you can usually
make it immutable simply by switching out `defstruct` for
`defstruct-read-only`.

There are only a few syntactic differences:

1. To prevent accidentally inheriting mutable slots,
   `defstruct-read-only` does not allow inheritance.

2. The `:type` option may not be used.

3. The `:copier` option is disabled, because it would be useless.

4. Slot definitions can use slot options without having to provide an
   initform. In this case, any attempt to make an instance of the
   struct without providing a value for that slot will signal an
   error.

    (my-slot :type string)
    ≡ (my-slot (required-argument 'my-slot) :read-only t :type string)

The idea here is simply that an unbound slot in an immutable data
structure does not make sense.

A read-only struct is always externalizable; it has an implicit
definition for `make-load-form`.

On Lisps that support it, the structure is also marked as "pure":
that is, instances may be moved into read-only memory.

`defstruct-read-only` is designed to stay as close to the syntax of
`defstruct` as possible. The idea is to make it easy to flag data as
immutable, whether in your own code or in code you are refactoring. In
new code, however, you may sometimes prefer `defconstructor`, which is
designed to facilitate working with immutable data.

[View source](definitions.lisp#L271)

### `(defvar-unbound var &body (docstring))`

Define VAR as if by `defvar` with no init form, and set DOCSTRING
as its documentation.

I believe the name comes from Edi Weitz.

[View source](definitions.lisp#L340)

### `(deconstruct x)`

NO DOCS!

[View source](definitions.lisp#L393)

### `(defconstructor type-name &body slots)`

A variant of `defstruct` for modeling immutable data.

The structure defined by `defconstructor` has only one constructor,
which takes its arguments as required arguments (a BOA constructor).
Thus, `defconstructor` is only appropriate for data structures that
require no initialization.

The printed representation of an instance resembles its constructor:

    (person "Common Lisp" 33)
    => (PERSON "Common Lisp" 33)

While the constructor is BOA, the copier takes keyword arguments,
allowing you to override the values of a selection of the slots of the
structure being copied, while retaining the values of the others.

    (defconstructor person
      (name string)
      (age (integer 0 1000)))

    (defun birthday (person)
      (copy-person person :age (1+ (person-age person))))

    (birthday (person "Common Lisp" 33))
    => (PERSON "Common Lisp" 34)

Obviously the copier becomes more useful the more slots the type has.

When `*print-readably*` is true, the printed representation is
readable:

    (person "Common Lisp" 33)
    => #.(PERSON "Common Lisp" 33)

(Why override how a structure is normally printed? Structure types
are not necessarily readable unless they have a default (`make-X`)
constructor. Since the type defined by `defconstructor` has only one
constructor, we have to take over to make sure it re-readable.)

Besides being re-readable, the type is also externalizable, with a
method for `make-load-form`:

    (make-load-form (person "Common Lisp" 33))
    => (PERSON "Common Lisp" 33)

Users of Trivia get an extra benefit: defining a type with
`defconstructor` also defines a symmetrical pattern for destructuring
that type.

    (trivia:match (person "Common Lisp" 33)
      ((person name age)
       (list name age)))
    => ("Common Lisp" 33)

Note that the arguments to the pattern are optional:

    (trivia:match (person "Common Lisp" 33)
      ((person name) name))
    => "Common Lisp"

If you don't use Trivia, you can still do destructuring with
`deconstruct`, which returns the slots of a constructor as multiple
values:

    (deconstruct (person "Common Lisp" 33))
    => "Common Lisp", 33

Note also that no predicate is defined for the type, so to test for
the type you must either use `typep` or pattern matching as above.

While it is possible to inherit from a type defined with
`defconstructor` (this is Lisp, I can't stop you), it's a bad idea. In
particular, on Lisps which support it, a type defined with
`defconstructor` is declared to be frozen (sealed), so your new
subtype may not be recognized in type tests.

Because `defconstructor` is implemented on top of
`defstruct-read-only`, it shares the limitations of
`defstruct-read-only`. In particular it cannot use inheritance.

The design of `defconstructor` is mostly inspired by Scala's [case
classes](https://docs.scala-lang.org/tour/case-classes.html), with
some implementation tricks from `cl-algebraic-data-type`.

[View source](definitions.lisp#L401)

## Binding

### `(lret (&rest bindings) &body body)`

Return the initial value of the last binding in BINDINGS. The idea
is to create something, initialize it, and then return it.

    (lret ((x 1)
           (y (make-array 1)))
      (setf (aref y 0) x))
    => #(1)

`lret` may seem trivial, but it fufills the highest purpose a macro
can: it eliminates a whole class of bugs (initializing an object, but
forgetting to return it).

Cf. `aprog1` in Anaphora.

[View source](binding.lisp#L5)

### `(lret* (&rest bindings) &body body)`

Cf. `lret`.

[View source](binding.lisp#L26)

### `(letrec (&rest bindings) &body body)`

Recursive LET.
The idea is that functions created in BINDINGS can close over one
another, and themselves.

Note that `letrec` only binds variables: it can define recursive
functions, but can't bind them as functions. (But see `fbindrec`.)

[View source](binding.lisp#L42)

### `(letrec* (&rest bindings) &body body)`

Like LETREC, but the bindings are evaluated in order.
See Waddell et al., *Fixing Letrec* for motivation.

Cf. `fbindrec*`.

[View source](binding.lisp#L53)

### `(receive formals expr &body body)`

Stricter version of `multiple-value-bind`.

Use `receive` when you want to enforce that EXPR should return a
certain number of values, or a minimum number of values.

If FORMALS is a proper list, then EXPR must return exactly as many
values -- no more and no less -- as there are variables in FORMALS.

If FORMALS is an improper list (VARS . REST), then EXPR must return at
least as many values as there are VARS, and any further values are
bound, as a list, to REST.

Lastly, if FORMALS is a symbol, bind that symbol to all the values
returned by EXPR, as if by `multiple-value-list`.

From Scheme (SRFI-8).

[View source](binding.lisp#L62)

### `(mvlet* (&rest bindings) &body body)`

Expand a series of nested `multiple-value-bind` forms.

`mvlet*` is similar in intent to Scheme’s `let-values`, but with a
different and less parenthesis-intensive syntax. Each binding is a
list of

    (var var*... expr)

A simple example should suffice to show both the implementation and
the motivation:

    (defun uptime (seconds)
      (mvlet* ((minutes seconds (truncate seconds 60))
               (hours minutes (truncate minutes 60))
               (days hours (truncate hours 24)))
        (declare ((integer 0 *) days hours minutes seconds))
        (fmt "~d day~:p, ~d hour~:p, ~d minute~:p, ~d second~:p"
             days hours minutes seconds)))

Note that declarations work just like `let*`.

[View source](binding.lisp#L129)

### `(mvlet (&rest bindings) &body body)`

Parallel (`let`-like) version of `mvlet*`.

[View source](binding.lisp#L188)

### `(and-let* (&rest clauses) &body body)`

Scheme's guarded LET* (SRFI-2).

Each clause should have one of the following forms:

- `identifier`, in which case IDENTIFIER's value is tested.

- `(expression)`, in which case the value of EXPRESSION is tested.

- `(identifier expression)' in which case EXPRESSION is evaluated,
    and, if its value is not false, IDENTIFIER is bound to that value
    for the remainder of the clauses and the optional body.

Note that, of course, the semantics are slightly different in Common
Lisp than in Scheme, because our AND short-circuits on null, not
false.

[View source](binding.lisp#L224)

## Control Flow

### `(eval-always &body body)`

Shorthand for
        (eval-when (:compile-toplevel :load-toplevel :execute) ...)

[View source](control-flow.lisp#L4)

### `(eval-and-compile &body body)`

Emacs's `eval-and-compile`.
Alias for `eval-always`.

[View source](control-flow.lisp#L10)

### `(no x)`

Another alias for `not` and `null`.

From Arc.

[View source](control-flow.lisp#L16)

### `(nor &rest forms)`

Equivalent to (not (or ...)).

From Arc.

[View source](control-flow.lisp#L25)

### `(nand &rest forms)`

Equivalent to (not (and ...)).

[View source](control-flow.lisp#L36)

### `(typecase-of type x &body clauses)`

Like `etypecase-of`, but may, and must, have an `otherwise` clause
in case X is not of TYPE.

[View source](control-flow.lisp#L132)

### `(etypecase-of type x &body body)`

Like `etypecase` but, at compile time, warn unless each clause in
BODY is a subtype of TYPE, and the clauses in BODY form an exhaustive
partition of TYPE.

[View source](control-flow.lisp#L145)

### `(case-of type x &body clauses)`

Like `case` but may, and must, have an `otherwise` clause.

[View source](control-flow.lisp#L157)

### `(ecase-of type x &body body)`

Like `ecase` but, given a TYPE (which should be defined as `(member
...)`), warn, at compile time, unless the keys in BODY are all of TYPE
and, taken together, they form an exhaustive partition of TYPE.

[View source](control-flow.lisp#L169)

### `(ctypecase-of type keyplace &body body)`

Like `etypecase-of`, but providing a `store-value` restart to correct KEYPLACE and try again.

[View source](control-flow.lisp#L181)

### `(ccase-of type keyplace &body body)`

Like `ecase-of`, but providing a `store-value` restart to correct KEYPLACE and try again.

[View source](control-flow.lisp#L186)

### `(destructuring-ecase-of type expr &body body)`

Like `destructuring-ecase`, from Alexandria, but with exhaustivness
checking.

TYPE is a designator for a type, which should be defined as `(member
...)`. At compile time, the macro checks that, taken together, the
symbol at the head of each of the destructuring lists in BODY form an
exhaustive partition of TYPE, and warns if it is not so.

[View source](control-flow.lisp#L204)

### `(destructuring-case-of type expr &body body)`

Like `destructuring-ecase-of`, but an `otherwise` clause must also be supplied.

Note that the otherwise clauses must also be a list:

    ((otherwise &rest args) ...)

[View source](control-flow.lisp#L214)

### `(destructuring-ccase-of type keyplace &body body)`

Like `destructuring-case-of`, but providing a `store-value` restart
to collect KEYPLACE and try again.

[View source](control-flow.lisp#L222)

### `(case-using pred keyform &body clauses)`

ISLISP's case-using.

     (case-using #'eql x ...)
     ≡ (case x ...).

Note that, no matter the predicate, the keys are not evaluated. (But see `selector`.)

This version supports both single-item clauses (x ...) and
multiple-item clauses ((x y) ...), as well as (t ...) or (otherwise
...) for the default clause.

[View source](control-flow.lisp#L227)

### `(string-case stringform &body clauses)`

Efficient `case`-like macro with string keys.

Note that string matching is always case-sensitive.

This uses Paul Khuong's `string-case` macro internally.

[View source](control-flow.lisp#L257)

### `(string-ecase stringform &body clauses)`

Efficient `ecase`-like macro with string keys.

Note that string matching is always case-sensitive.

Cf. `string-case`.

[View source](control-flow.lisp#L284)

### `(eif test then &optional (else nil else?))`

Like `cl:if`, but expects two branches.
Stands for “exhaustive if”.

[View source](control-flow.lisp#L294)

### `(eif-let binds &body (then &optional (else nil else?)))`

Like `alexandria:if-let`, but expects two branches.

[View source](control-flow.lisp#L302)

### `(econd &body clauses)`

Like `cond`, but signal an error of type `econd-failure` if no
clause succeeds.

[View source](control-flow.lisp#L323)

### `(cond-let var &body clauses)`

Cross between COND and LET.

     (cond-let x ((test ...)))
     ≡ (let (x)
         (cond ((setf x test) ...)))

Cf. `acond` in Anaphora.

[View source](control-flow.lisp#L332)

### `(econd-let symbol &body clauses)`

Like `cond-let` for `econd`.

[View source](control-flow.lisp#L353)

### `(cond-every &body clauses)`

Like `cond`, but instead of stopping after the first clause that
succeeds, run all the clauses that succeed.

Return the value of the last successful clause.

If a clause begins with `cl:otherwise`, it runs only if no preceding
form has succeeded.

Note that this does *not* do the same thing as a series of `when`
forms: `cond-every` evaluates *all* the tests *before* it evaluates
any of the forms.

From Zetalisp.

[View source](control-flow.lisp#L366)

### `(bcond &body clauses)`

Scheme's extended COND.

This is exactly like COND, except for clauses having the form

     (test :=> recipient)

In that case, if TEST evaluates to a non-nil result, then RECIPIENT, a
function, is called with that result, and the result of RECIPIENT is
return as the value of the `cond`.

As an extension, a clause like this:

     (test :=> var ...)

Can be used as a shorthand for

     (test :=> (lambda (var) ...))

The name `bcond` for a “binding cond” goes back at least to the days
of the Lisp Machines. I do not know who was first to use it, but the
oldest examples I have found are by Michael Parker and Scott L.
Burson.

[View source](control-flow.lisp#L399)

### `(case-let (var expr) &body cases)`

Like (let ((VAR EXPR)) (case VAR ...))

[View source](control-flow.lisp#L452)

### `(ecase-let (var expr) &body cases)`

Like (let ((VAR EXPR)) (ecase VAR ...))

[View source](control-flow.lisp#L458)

### `(comment &body body)`

A macro that ignores its body and does nothing. Useful for
comments-by-example.

Also, as noted in EXTENSIONS.LISP of 1992, "This may seem like a
silly macro, but used inside of other macros or code generation
facilities it is very useful - you can see comments in the (one-time)
macro expansion!"

[View source](control-flow.lisp#L464)

### `(example &body body)`

Like `comment`.

[View source](control-flow.lisp#L474)

### `(nix place)`

Set PLACE to nil and return the old value of PLACE.

This may be more efficient than (shiftf place nil), because it only
sets PLACE when it is not already null.

[View source](control-flow.lisp#L478)

### `(ensure place &body newval)`

Essentially (or place (setf place newval)).

PLACE is treated as unbound if it returns `nil`, signals
`unbound-slot`, or signals `unbound-variable`.

Note that ENSURE is `setf`-able, so you can do things like
     (incf (ensure x 0))

Cf. `ensure2`.

[View source](control-flow.lisp#L493)

### `(ensure2 place &body newval)`

Like `ensure`, but specifically for accessors that return a second
value like `gethash`.

[View source](control-flow.lisp#L525)

### `(~> needle &rest holes)`

Threading macro from Clojure (by way of Racket).

Thread NEEDLE through HOLES, where each hole is either a
symbol (equivalent to `(hole needle)`) or a list (equivalent to `(hole
needle args...)`).

As an extension, an underscore in the argument list is replaced with
the needle, so you can pass the needle as an argument other than the
first.

[View source](control-flow.lisp#L592)

### `(~>> needle &rest holes)`

Like `~>` but, by default, thread NEEDLE as the last argument
instead of the first.

[View source](control-flow.lisp#L606)

### `(nest &rest things)`

Like ~>>, but backward.

This is useful when layering `with-x` macros where the order is not
important, and extra indentation would be misleading.

For example:

    (nest
     (with-open-file (in file1 :direction input))
     (with-open-file (in file2 :direction output))
     ...)

Is equivalent to:

    (with-open-file (in file1 :direction input)
      (with-open-file (in file2 :direction output)
        ...))

If the outer macro has no arguments, you may omit the parentheses.

    (nest
      with-standard-io-syntax
      ...)
    ≡ (with-standard-io-syntax
        ...)

From UIOP, based on a suggestion by Marco Baringer.

[View source](control-flow.lisp#L613)

### `(select keyform &body clauses)`

Like `case`, but with evaluated keys.

Note that, like `case`, `select` interprets a list as the first
element of a clause as a list of keys. To use a form as a key, you
must add an extra set of parentheses.

     (select 2
       ((+ 2 2) t))
     => T

     (select 4
       (((+ 2 2)) t))
     => T

From Zetalisp.

[View source](control-flow.lisp#L647)

### `(selector keyform fn &body clauses)`

Like `select`, but compare using FN.

Note that (unlike `case-using`), FN is not evaluated.

From Zetalisp.

[View source](control-flow.lisp#L666)

### `(sort-values pred &rest values)`

Sort VALUES with PRED and return as multiple values.

Equivalent to 

    (values-list (sort (list VALUES...) pred))

But with less consing, and potentially faster.

[View source](control-flow.lisp#L785)

### `(eq* &rest xs)`

Variadic version of `EQ`.

With no arguments, return T.

With one argument, return T.

With two arguments, same as `EQ`.

With three or more arguments, return T only if all of XS are
equivalent under `EQ`.

Has a compiler macro, so there is no loss of efficiency relative to
writing out the tests by hand.

[View source](control-flow.lisp#L856)

### `(eql* &rest xs)`

Variadic version of `EQL`.

With no arguments, return T.

With one argument, return T.

With two arguments, same as `EQL`.

With three or more arguments, return T only if all of XS are
equivalent under `EQL`.

Has a compiler macro, so there is no loss of efficiency relative to
writing out the tests by hand.

[View source](control-flow.lisp#L858)

### `(equal* &rest xs)`

Variadic version of `EQUAL`.

With no arguments, return T.

With one argument, return T.

With two arguments, same as `EQUAL`.

With three or more arguments, return T only if all of XS are
equivalent under `EQUAL`.

Has a compiler macro, so there is no loss of efficiency relative to
writing out the tests by hand.

[View source](control-flow.lisp#L860)

### `(equalp* &rest xs)`

Variadic version of `EQUALP`.

With no arguments, return T.

With one argument, return T.

With two arguments, same as `EQUALP`.

With three or more arguments, return T only if all of XS are
equivalent under `EQUALP`.

Has a compiler macro, so there is no loss of efficiency relative to
writing out the tests by hand.

[View source](control-flow.lisp#L862)

## Threads

### `(synchronized (&optional (object nil objectp)) &body body)`

Run BODY holding a unique lock associated with OBJECT.
If no OBJECT is provided, run BODY as an anonymous critical section.

If BODY begins with a literal string, attach the string to the lock
object created (as the argument to `bt:make-recursive-lock`).

[View source](threads.lisp#L27)

### `(monitor object)`

Return a unique lock associated with OBJECT.

[View source](threads.lisp#L43)

## Iter

### `(nlet name (&rest bindings) &body body)`

Within BODY, bind NAME as a function, somewhat like LABELS, but
with the guarantee that recursive calls to NAME will not grow the
stack.

`nlet` resembles Scheme’s named let, and is used for the same purpose:
writing loops using tail recursion. You could of course do this with
`labels` as well, at least under some Lisp implementations, but `nlet`
guarantees tail call elimination anywhere and everywhere.

    (nlet rec ((i 1000000))
      (if (= i 0)
          0
          (rec (1- i))))
    => 0

Beware: because of the way it is written (literally, a GOTO with
arguments), `nlet` is limited: self calls must be tail calls. That is,
you cannot use `nlet` for true recursion.

The name comes from `Let Over Lambda', but this is a more careful
implementation: the function is not bound while the initial arguments
are being evaluated, and it is safe to close over the arguments.

[View source](iter.lisp#L22)

### `(defloop name args &body body)`

Define a function, ensuring proper tail recursion.
This is entirely equivalent to `defun` over `nlet`.

[View source](iter.lisp#L77)

### `(with-collector (collector) &body body)`

Within BODY, bind COLLECTOR to a function of one argument that
accumulates all the arguments it has been called with in order, like
the collect clause in `loop`, finally returning the collection.

To see the collection so far, call COLLECTOR with no arguments.

Note that this version binds COLLECTOR to a closure, not a macro: you
can pass the collector around or return it like any other function.

[View source](iter.lisp#L115)

### `(collecting &body body)`

Like `with-collector`, with the collector bound to the result of
interning `collect` in the current package.

[View source](iter.lisp#L138)

### `(with-collectors (&rest collectors) &body body)`

Like `with-collector`, with multiple collectors.
Returns the final value of each collector as multiple values.

     (with-collectors (x y z)
       (x 1)
       (y 2)
       (z 3))
     => '(1) '(2) '(3)

[View source](iter.lisp#L145)

### `(summing &body body)`

Within BODY, bind `sum` to a function that gathers numbers to sum.

If the first form in BODY is a literal number, it is used instead of 0
as the initial sum.

To see the running sum, call `sum` with no arguments.

Return the total.

[View source](iter.lisp#L170)

## Conditions

### `(ignoring type &body body)`

An improved version of `ignore-errors`.

The behavior is the same: if an error occurs in the body, the form
returns two values, `nil` and the condition itself.

`ignoring` forces you to specify the kind of error you want to ignore:

    (ignoring parse-error
      ...)

I call it an improvement because I think `ignore-errors` is too broad:
by hiding all errors it becomes itself a source of bugs.

Of course you can still ignore all errors, at the cost of one extra
character:

    (ignoring error
      ...)

NB `(ignoring t)` is a bad idea.

[View source](conditions.lisp#L3)

### `(maybe-invoke-restart restart &rest values)`

When RESTART is active, invoke it with VALUES.

[View source](conditions.lisp#L29)

## Op

This differs from [the original][GOO] in expecting an extra layer of
parentheses. I find it easier to put the extra parentheses in than to
remember to leave them out. Doing it this way also lets completion
work.

Of course, the extra parentheses make it longer, but the point of
positional lambdas isn't to save typing: it's to save the mental
effort of giving things *names* when all we are interested in is the
*shape* of the code.

[GOO]: http://people.csail.mit.edu/jrb/goo/manual.46/goomanual_15.html#17


### `(op &body body)`

GOO's simple macro for positional lambdas.

An OP is like a lambda without an argument list. Within the body of the OP
form, an underscore introduces a new argument.

     (reduce (op (set-intersection _ _ :test #'equal))
             sets)

You can refer back to each argument by number, starting with _1.

     (funcall (op (+ _ _1)) 2) => 4

You can also use positional arguments directly:

     (reduce (op (funcall _2 _1)) ...)

Argument lists can be sparse:

     (apply (op (+ _1 _3 _5)) '(1 2 3 4 5)) => 9

Note that OP with a single argument is equivalent to CONSTANTLY:

     (funcall (op 1)) => 1

and that OP with a single placeholder is equivalent to IDENTITY:

     (funcall (op _) 1) => 1

OP can also be used to define variadic functions by using _* as the
placeholder. It is not necessary to use APPLY.

     (apply (op (+ _*)) '(1 2 3 4)) => 10

OP is intended for simple functions -- one-liners. Parameters are
extracted according to a depth-first walk of BODY. Macro expansion
may, or may not, be done depending on the implementation; it should
not be relied on. Lexical bindings may, or may not, shadow
placeholders -- again, it depends on the implementation. (This means,
among other things, that nested use of `op` is not a good idea.)
Because of the impossibility of a truly portable code walker, `op`
will never be a true replacement for `lambda`. But even if it were
possible to do better, `op` would still only be suited for one-liners.
If you need more than a one-liner, then you should be giving your
arguments names.

{One thing you *can* count on the ability to use `op` with
quasiquotes. If using placeholders inside quasiquotes does not work on
your Lisp implementation, that's a bug, not a limitation.)

[View source](op.lisp#L186)

### `(opf place expr)`

Like `(callf PLACE (op EXPR))'.
From GOO.

[View source](op.lisp#L238)

## Functions

### `(partial fn &rest args)`

Partial application.

Unlike `alexandria:curry`, which is only inlined when you ask it to
be, `partial` is always inlined if possible.

From Clojure.

[View source](functions.lisp#L32)

### `(trampoline fn &rest args)`

Use the trampoline technique to simulate mutually recursive functions.

Call FN with supplied ARGS, if any.

If FN returns a functions, call that function with no arguments.
Repeat until the return value is not a function, and finally return
that non-function value.

Note that, to return a function as a final value, you must wrap it in
some data structure and unpack it.

Most likely to be useful for Lisp implementations that do not provide
tail call elimination.

From Clojure.

[View source](functions.lisp#L64)

### `(define-train name args &body body)`

Define a function that takes only a fixed number of functions as arguments and returns another functions.

Also define a compiler macro that inlines the resulting lambda
expression, so compilers can eliminate it.

The term "train" is from J.

[View source](functions.lisp#L87)

### `(flip f)`

Flip around the arguments of a binary function.

That is, given a binary function, return another, equivalent function
that takes its two arguments in the opposite order.

From Haskell.

[View source](functions.lisp#L113)

### `(nth-arg n)`

Return a function that returns only its NTH argument, ignoring all others.

If you've ever caught yourself trying to do something like

    (mapcar #'second xs ys)

then `nth-arg` is what you need.

If `hash-table-keys` were not already defined by Alexandria, you could
define it thus:

    (defun hash-table-keys (table)
      (maphash-return (nth-arg 0) table))

[View source](functions.lisp#L123)

### `(distinct &key key test)`

Return a function that echoes only values it has not seen before.

    (defalias test (distinct))
    (test 'foo) => foo, t
    (test 'foo) => nil, nil

The second value is T when the value is distinct.

TEST must be a valid test for a hash table.

This has many uses, for example:

    (count-if (distinct) seq)
    ≡ (length (remove-duplicates seq))

[View source](functions.lisp#L148)

### `(throttle fn wait &key synchronized memoized)`

Wrap FN so it can be called no more than every WAIT seconds.
If FN was called less than WAIT seconds ago, return the values from the
last call. Otherwise, call FN normally and update the cached values.

WAIT, of course, may be a fractional number of seconds.

The throttled function is not thread-safe by default; use SYNCHRONIZED
to get a version with a lock.

You can pass MEMOIZED if you want the function to remember values
between calls.

[View source](functions.lisp#L173)

### `(juxt &rest fns)`

Clojure's `juxt`.

Return a function of one argument, which, in turn, returns a list
where each element is the result of applying one of FNS to the
argument.

It’s actually quite simple, but easier to demonstrate than to explain.
The classic example is to use `juxt` to implement `partition`:

    (defalias partition* (juxt #'filter #'remove-if))
    (partition* #'evenp '(1 2 3 4 5 6 7 8 9 10))
    => '((2 4 6 8 10) (1 3 5 7 9))

The general idea is that `juxt` takes things apart.

[View source](functions.lisp#L237)

### `(dynamic-closure symbols fn)`

Create a dynamic closure.

Some ancient Lisps had closures without lexical binding. Instead, you
could "close over" pieces of the current dynamic environment. When
the resulting closure was called, the symbols closed over would be
bound to their values at the time the closure was created. These
bindings would persist through subsequent invocations and could be
mutated. The result was something between a closure and a
continuation.

This particular piece of Lisp history is worth reviving, I think, if
only for use with threads. For example, to start a thread and
propagate the current value of `*standard-output*`:

     (bt:make-thread (dynamic-closure '(*standard-output*) (lambda ...)))
     = (let ((temp *standard-output*))
         (bt:make-thread
          (lambda ...
            (let ((*standard-output* temp))
              ...))))

[View source](functions.lisp#L267)

### `(hook f g)`

Monadic hook.
From J.

AKA Schoenfinkel's S combinator.

[View source](functions.lisp#L301)

### `(fork g f h)`

Monadic fork.
From J.

[View source](functions.lisp#L309)

### `(hook2 f g)`

Dyadic hook.
From J.

[View source](functions.lisp#L317)

### `(fork2 g f h)`

Dyadic fork.
From J.

[View source](functions.lisp#L324)

### `(capped-fork g f h)`

J's capped fork (monadic).

[View source](functions.lisp#L332)

### `(capped-fork2 g f h)`

J's capped fork (dyadic).

[View source](functions.lisp#L338)

## Trees

### `(walk-tree fun tree &optional tag)`

Call FUN in turn over each atom and cons of TREE.

FUN can skip the current subtree with (throw TAG nil).

[View source](trees.lisp#L17)

### `(map-tree fun tree &optional tag)`

Walk FUN over TREE and build a tree from the results.

The new tree may share structure with the old tree.

     (eq tree (map-tree #'identity tree)) => T

FUN can skip the current subtree with (throw TAG SUBTREE), in which
case SUBTREE will be used as the value of the subtree.

[View source](trees.lisp#L38)

### `(leaf-walk fun tree)`

Call FUN on each leaf of TREE.

[View source](trees.lisp#L67)

### `(leaf-map fn tree)`

Call FN on each leaf of TREE.
Return a new tree possibly sharing structure with TREE.

[View source](trees.lisp#L81)

### `(occurs-if test tree &key key)`

Is there a node (leaf or cons) in TREE that satisfies TEST?

[View source](trees.lisp#L92)

### `(prune-if test tree &key key)`

Remove any atoms satisfying TEST from TREE.

[View source](trees.lisp#L102)

### `(occurs leaf tree &key key test)`

Is LEAF present in TREE?

[View source](trees.lisp#L117)

### `(prune leaf tree &key key test)`

Remove LEAF from TREE wherever it occurs.

[View source](trees.lisp#L125)

## Hash Tables

### `(do-hash-table (key value table &optional return) &body body)`

Iterate over hash table TABLE, in no particular order.

At each iteration, a key from TABLE is bound to KEY, and the value of
that key in TABLE is bound to VALUE.

[View source](hash-tables.lisp#L3)

### `(dict &rest keys-and-values)`

A concise constructor for hash tables.

    (gethash :c (dict :a 1 :b 2 :c 3)) => 3, T

By default, return an 'equal hash table containing each successive
pair of keys and values from KEYS-AND-VALUES.

If the number of KEYS-AND-VALUES is odd, then the first argument is
understood as the test.

     (gethash "string" (dict "string" t)) => t
     (gethash "string" (dict 'eq "string" t)) => nil

[View source](hash-tables.lisp#L55)

### `(dict* dict &rest args)`

Merge new bindings into DICT.
Roughly equivalent to `(merge-tables DICT (dict args...))'.

[View source](hash-tables.lisp#L89)

### `(dictq &rest keys-and-values)`

A literal hash table.
Like `dict`, but the keys and values are implicitly quoted.

[View source](hash-tables.lisp#L96)

### `(href table &rest keys)`

A concise way of doings lookups in (potentially nested) hash tables.

    (href (dict :x 1) :x) => x
    (href (dict :x (dict :y 2)) :x :y)  => y

[View source](hash-tables.lisp#L101)

### `(href-default default table &rest keys)`

Like `href`, with a default.
As soon as one of KEYS fails to match, DEFAULT is returned.

[View source](hash-tables.lisp#L110)

### `(@ table &rest keys)`

A concise way of doings lookups in (potentially nested) hash tables.

    (@ (dict :x 1) :x) => x
    (@ (dict :x (dict :y 2)) :x :y)  => y 

[View source](hash-tables.lisp#L148)

### `(pophash key hash-table)`

Lookup KEY in HASH-TABLE, return its value, and remove it.

This is only a shorthand. It is not in itself thread-safe.

From Zetalisp.

[View source](hash-tables.lisp#L173)

### `(swaphash key value hash-table)`

Set KEY and VALUE in HASH-TABLE, returning the old values of KEY.

This is only a shorthand. It is not in itself thread-safe.

From Zetalisp.

[View source](hash-tables.lisp#L184)

### `(hash-fold fn init hash-table)`

Reduce TABLE by calling FN with three values: a key from the hash
table, its value, and the return value of the last call to FN. On the
first call, INIT is supplied in place of the previous value.

From Guile.

[View source](hash-tables.lisp#L194)

### `(maphash-return fn hash-table)`

Like MAPHASH, but collect and return the values from FN.
From Zetalisp.

[View source](hash-tables.lisp#L208)

### `(merge-tables table &rest tables)`

Merge TABLE and TABLES, working from left to right.
The resulting hash table has the same parameters as TABLE.

If the same key is present in two tables, the value from the rightmost
table is used.

All of the tables being merged must have the same value for
`hash-table-test'.

Clojure`s `merge`.


[View source](hash-tables.lisp#L219)

### `(flip-hash-table table &key test key)`

Return a table like TABLE, but with keys and values flipped.

     (gethash :y (flip-hash-table (dict :x :y)))
     => :x, t

TEST allows you to filter which keys to set.

     (def number-names (dictq 1 one 2 two 3 three))

     (def name-numbers (flip-hash-table number-names))
     (def name-odd-numbers (flip-hash-table number-names :filter #'oddp))

     (gethash 'two name-numbers) => 2, t
     (gethash 'two name-odd-numbers) => nil, nil

KEY allows you to transform the keys in the old hash table.

     (def negative-number-names (flip-hash-table number-names :key #'-))
     (gethash 'one negative-number-names) => -1, nil

KEY defaults to `identity`.

[View source](hash-tables.lisp#L249)

### `(set-hash-table set &rest hash-table-args &key test key strict &allow-other-keys)`

Return SET, a list considered as a set, as a hash table.
This is the equivalent of Alexandria's `alist-hash-table` and
`plist-hash-table` for a list that denotes a set.

STRICT determines whether to check that the list actually is a set.

The resulting hash table has the elements of SET for both its keys and
values. That is, each element of SET is stored as if by
     (setf (gethash (key element) table) element)

[View source](hash-tables.lisp#L279)

### `(hash-table-set table &key strict test key)`

Return the set denoted by TABLE.
Given STRICT, check that the table actually denotes a set.

Without STRICT, equivalent to `hash-table-values`.

[View source](hash-tables.lisp#L311)

### `(hash-table-predicate hash-table)`

Return a predicate for membership in HASH-TABLE.
The predicate returns the same two values as `gethash`, but in the
opposite order.

[View source](hash-tables.lisp#L322)

### `(hash-table-function hash-table &key read-only strict key-type value-type strict-types)`

Return a function for accessing HASH-TABLE.

Calling the function with a single argument is equivalent to `gethash`
against a copy of HASH-TABLE at the time HASH-TABLE-FUNCTION was
called.

    (def x (make-hash-table))

    (funcall (hash-table-function x) y)
    ≡ (gethash y x)

If READ-ONLY is nil, then calling the function with two arguments is
equivalent to `(setf (gethash ...))' against HASH-TABLE.

If STRICT is non-nil, then the function signals an error if it is
called with a key that is not present in HASH-TABLE. This applies to
setting keys, as well as looking them up.

The function is able to restrict what types are permitted as keys and
values. If KEY-TYPE is specified, an error will be signaled if an
attempt is made to get or set a key that does not satisfy KEY-TYPE. If
VALUE-TYPE is specified, an error will be signaled if an attempt is
made to set a value that does not satisfy VALUE-TYPE. However, the
hash table provided is *not* checked to ensure that the existing
pairings KEY-TYPE and VALUE-TYPE -- not unless STRICT-TYPES is also
specified.

[View source](hash-tables.lisp#L332)

### `(make-hash-table-function &rest args &key &allow-other-keys)`

Call `hash-table-function` on a fresh hash table.
ARGS can be args to `hash-table-function` or args to
`make-hash-table`, as they are disjoint.

[View source](hash-tables.lisp#L423)

### `(delete-from-hash-table table &rest keys)`

Return TABLE with KEYS removed (as with `remhash`).
Cf. `delete-from-plist` in Alexandria.

[View source](hash-tables.lisp#L431)

## Files

### `(path-join &rest pathnames)`

Build a pathname by merging from right to left.
With `path-join` you can pass the elements of the pathname being built
in the order they appear in it:

    (path-join (user-homedir-pathname) config-dir config-file)
    ≡ (uiop:merge-pathnames* config-file
       (uiop:merge-pathnames* config-dir
        (user-homedir-pathname)))

Note that `path-join` does not coerce the parts of the pathname into
directories; you have to do that yourself.

    (path-join "dir1" "dir2" "file") -> #p"file"
    (path-join "dir1/" "dir2/" "file") -> #p"dir1/dir2/file"

[View source](files.lisp#L3)

### `(write-stream-into-file stream pathname &key if-exists if-does-not-exist)`

Read STREAM and write the contents into PATHNAME.

STREAM will be closed afterwards, so wrap it with
`make-concatenated-stream` if you want it left open.

[View source](files.lisp#L24)

### `(file= file1 file2 &key buffer-size)`

Compare FILE1 and FILE2 octet by octet, (possibly) using buffers
of BUFFER-SIZE.

[View source](files.lisp#L38)

### `(file-size file &key element-type)`

The size of FILE, in units of ELEMENT-TYPE (defaults to bytes).

The size is computed by opening the file and getting the length of the
resulting stream.

If all you want is to read the file's size in octets from its
metadata, consider `trivial-file-size:file-size-in-octets` instead.

[View source](files.lisp#L102)

## Symbols

### `(find-keyword string)`

If STRING has been interned as a keyword, return it.

Like `make-keyword`, but preferable in most cases, because it doesn't
intern a keyword -- which is usually both unnecessary and unwise.

[View source](symbols.lisp#L9)

### `(bound-value s &optional default)`

If S is bound, return (values s t). Otherwise, return DEFAULT and nil.

[View source](symbols.lisp#L26)

## Arrays

### `(array-index-row-major array row-major-index)`

The inverse of ARRAY-ROW-MAJOR-INDEX.

Given an array and a row-major index, return a list of subscripts.

     (apply #'aref (array-index-row-major i))
     ≡ (array-row-major-aref i)

[View source](arrays.lisp#L4)

### `(undisplace-array array)`

Recursively get the fundamental array that ARRAY is displaced to.

Return the fundamental array, and the start and end positions into it.

Borrowed from Erik Naggum.

[View source](arrays.lisp#L24)

## Queue

Norvig-style queues, but wrapped in objects so they don't overflow the
printer, and with a more concise, Arc-inspired API.


### `(queuep g)`

Test for a queue.

[View source](queue.lisp#L9)

### `(queue &rest initial-contents)`

Build a new queue with INITIAL-CONTENTS.

[View source](queue.lisp#L70)

### `(clear-queue queue)`

Return QUEUE's contents and reset it.

[View source](queue.lisp#L76)

### `(qlen queue)`

The number of items in QUEUE.

[View source](queue.lisp#L90)

### `(qlist queue)`

A list of the items in QUEUE.

[View source](queue.lisp#L95)

### `(enq item queue)`

Insert ITEM at the end of QUEUE.

[View source](queue.lisp#L99)

### `(deq queue)`

Remove item from the front of the QUEUE.

[View source](queue.lisp#L108)

### `(front queue)`

The first element in QUEUE.

[View source](queue.lisp#L120)

### `(queue-empty-p queue)`

Is QUEUE empty?

[View source](queue.lisp#L124)

### `(qconc queue list)`

Destructively concatenate LIST onto the end of QUEUE.
Return the queue.

[View source](queue.lisp#L128)

### `(qappend queue list)`

Append the elements of LIST onto the end of QUEUE.
Return the queue.

[View source](queue.lisp#L139)

## Box

### `(box value)`

Box a value.

[View source](box.lisp#L4)

### `(unbox x)`

The value in the box X.

[View source](box.lisp#L26)

## Numbers

### `(fixnump n)`

Same as `(typep N 'fixnum)'.

[View source](numbers.lisp#L3)

### `(finc ref &optional (delta 1))`

Like `incf`, but returns the old value instead of the new.

An alternative to using -1 as the starting value of a counter, which
can prevent optimization.

[View source](numbers.lisp#L7)

### `(fdec ref &optional (delta 1))`

Like `decf`, but returns the old value instead of the new.

[View source](numbers.lisp#L13)

### `(parse-float string &key start end junk-allowed type)`

Parse STRING as a float of TYPE.

The type of the float is determined by, in order:
- TYPE, if it is supplied;
- The type specified in the exponent of the string;
- or `*read-default-float-format*`.

     (parse-float "1.0") => 1.0s0
     (parse-float "1.0d0") => 1.0d0
     (parse-float "1.0s0" :type 'double-float) => 1.0d0

Of course you could just use `parse-number`, but sometimes only a
float will do.

[View source](numbers.lisp#L99)

### `(round-to number &optional divisor)`

Like `round`, but return the resulting number.

     (round 15 10) => 2
     (round-to 15 10) => 20

[View source](numbers.lisp#L136)

### `(bits int &key big-endian)`

Return a bit vector of the bits in INT.
Defaults to little-endian.

[View source](numbers.lisp#L145)

### `(unbits bits &key big-endian)`

Turn a sequence of BITS into an integer.
Defaults to little-endian.

[View source](numbers.lisp#L167)

### `(shrink n by)`

Decrease N by a factor.

[View source](numbers.lisp#L184)

### `(grow n by)`

Increase N by a factor.

[View source](numbers.lisp#L188)

### `(shrinkf g n)`

Shrink the value in a place by a factor.

[View source](numbers.lisp#L192)

### `(growf g n)`

Grow the value in a place by a factor.

[View source](numbers.lisp#L195)

### `(random-in-range low high)`

Random number in the range [low,high).

LOW and HIGH are automatically swapped if HIGH is less than LOW.

Note that the value of LOW+HIGH may be greater than the range that can
be represented as a number in CL. E.g., you can generate a random double float with

    (random-in-range most-negative-double-float most-positive-double-float)

even though (+ most-negative-double-float most-positive-double-float)
would cause a floating-point overflow.

From Zetalisp.

[View source](numbers.lisp#L198)

### `(float-precision-contagion &rest ns)`

Perform numeric contagion on the elements of NS.

That is, if any element of NS is a float, then every number in NS will
be returned as "a float of the largest format among all the
floating-point arguments to the function".

This does nothing but numeric contagion: the number of arguments
returned is the same as the number of arguments given.

[View source](numbers.lisp#L274)

## Octets

### `(octet-vector-p x)`

Is X an octet vector?

[View source](octets.lisp#L13)

### `(make-octet-vector size)`

Make an octet vector of SIZE elements.

[View source](octets.lisp#L18)

### `(octets n &key big-endian)`

Return N, an integer, as an octet vector.
Defaults to little-endian order.

[View source](octets.lisp#L25)

### `(unoctets bytes &key big-endian)`

Concatenate BYTES, an octet vector, into an integer.
Defaults to little-endian order.

[View source](octets.lisp#L47)

## Time

### `(universal-to-unix time)`

Convert a universal time to a Unix time.

[View source](time.lisp#L18)

### `(unix-to-universal time)`

Convert a Unix time to a universal time.

[View source](time.lisp#L22)

### `(get-unix-time)`

The current time as a count of seconds from the Unix epoch.

[View source](time.lisp#L26)

### `(date-leap-year-p year)`

Is YEAR a leap year in the Gregorian calendar?

[View source](time.lisp#L30)

### `(time-since time)`

Return seconds since TIME.

[View source](time.lisp#L37)

### `(time-until time)`

Return seconds until TIME.

[View source](time.lisp#L41)

### `(interval &key seconds minutes hours days weeks months years month-days year-days)`

A verbose but readable way of specifying intervals in seconds.

Intended as a more readable alternative to idioms
like (let ((day-in-seconds #.(* 24 60 60))) ...)

Has a compiler macro.

[View source](time.lisp#L45)

## Clos

### `(make class &rest initargs &key &allow-other-keys)`

Shorthand for `make-instance`.
After Eulisp.

[View source](clos.lisp#L3)

### `(class-name-safe x)`

The class name of the class of X.
If X is a class, the name of the class itself.

[View source](clos.lisp#L15)

### `(find-class-safe x &optional env)`

The class designated by X.
If X is a class, it designates itself.

[View source](clos.lisp#L22)

### `(defmethods class (self . slots) &body body)`

Concisely define methods that specialize on the same class.

You can already use `defgeneric` to define an arbitrary number of
methods on a single generic function without having to repeat the name
of the function:

    (defgeneric fn (x)
      (:method ((x string)) ...)
      (:method ((x number)) ...))

Which is equivalent to:

    (defgeneric fn (x))

    (defmethod fn ((x string))
      ...)

    (defmethod fn ((x number))
      ...)

Similarly, you can use `defmethods` to define methods that specialize
on the same class, and access the same slots, without having to
repeat the names of the class or the slots:

    (defmethods my-class (self x y)
      (:method initialize-instance :after (self &key)
        ...)
      (:method print-object (self stream)
        ...)
      (:method some-method ((x string) self)
        ...))

Which is equivalent to:

    (defmethod initialize-instance :after ((self my-class) &key)
      (with-slots (x y) self
        ...))

    (defmethod print-object ((self my-class) stream)
      (with-slots (x y) self
        ...))

    (defmethod some-method ((x string) (self my-class))
      (with-slots (y) self              ;!
        ...))

Note in particular that `self` can appear in any position, and that
you can freely specialize the other arguments.

(The difference from using `with-slots` is the scope of the slot
bindings: they are established *outside* of the method definition,
which means argument bindings shadow slot bindings:

    (some-method "foo" (make 'my-class :x "bar"))
    => "foo"

Since slot bindings are lexically outside the argument bindings, this
is surely correct, even if it makes `defmethods` slightly harder to
explain in terms of simpler constructs.)

Is `defmethods` trivial? Yes, in terms of its implementation. This
docstring is far longer than the code it documents. But you may find
it does a lot to keep heavily object-oriented code readable and
organized, without any loss of power.

This construct is very loosely inspired by impl blocks in Rust.

[View source](clos.lisp#L32)

## Hooks

### `(add-hook name fn &key append)`

Add FN to the value of NAME, a hook.

[View source](hooks.lisp#L7)

### `(remove-hook name fn)`

Remove fn from the symbol value of NAME.

[View source](hooks.lisp#L15)

### `(run-hooks &rest hookvars)`

Run all the hooks in all the HOOKVARS.
The variable `*hook*` is bound to the name of each hook as it is being
run.

[View source](hooks.lisp#L23)

### `(run-hook-with-args *hook* &rest args)`

Apply each function in the symbol value of HOOK to ARGS.

[View source](hooks.lisp#L32)

### `(run-hook-with-args-until-failure *hook* &rest args)`

Like `run-hook-with-args`, but quit once a function returns nil.

[View source](hooks.lisp#L38)

### `(run-hook-with-args-until-success *hook* &rest args)`

Like `run-hook-with-args`, but quit once a function returns
non-nil.

[View source](hooks.lisp#L43)

## Fbind

### `(fbind bindings &body body)`

Binds values in the function namespace.

That is,
     (fbind ((fn (lambda () ...))))
     ≡ (flet ((fn () ...))),

except that a bare symbol in BINDINGS is rewritten as (symbol
symbol).

[View source](fbind.lisp#L308)

### `(fbind* bindings &body body)`

Like `fbind`, but creates bindings sequentially.

[View source](fbind.lisp#L345)

### `(fbindrec bindings &body body)`

Like `fbind`, but creates recursive bindings.

The consequences of referring to one binding in the expression that
generates another are undefined.

[View source](fbind.lisp#L408)

### `(fbindrec* bindings &body body)`

Like `fbindrec`, but the function defined in each binding can be
used in successive bindings.

[View source](fbind.lisp#L451)

## Lists

### `(filter-map fn list &rest lists)`

Map FN over (LIST . LISTS) like `mapcar`, but omit empty results.

     (filter-map fn ...)
     ≅ (remove nil (mapcar fn ...))

[View source](lists.lisp#L9)

### `(car-safe x)`

The car of X, or nil if X is not a cons.

This is different from Alexandria’s `ensure-car`, which returns the atom.

    (ensure-car '(1 . 2)) => 1
    (car-safe '(1 . 2)) => 1
    (ensure-car 1) => 1
    (car-safe 1) => nil

From Emacs Lisp.

[View source](lists.lisp#L35)

### `(cdr-safe x)`

The cdr of X, or nil if X is not a cons.
From Emacs Lisp.

[View source](lists.lisp#L48)

### `(append1 list item)`

Append an atom to a list.

    (append1 list item)
    ≡ (append list (list item))

[View source](lists.lisp#L53)

### `(in x &rest items)`

Is X equal to any of ITEMS?

`(in x xs...)` is always equivalent to `(and (member x xs :test equal) t)`,
but `in` can sometimes compile to more efficient code when the
candidate matches are constant.

From Arc.

[View source](lists.lisp#L60)

### `(memq item list)`

Like (member ... :test #'eq).
Should only be used for symbols.

[View source](lists.lisp#L87)

### `(delq item list)`

Like (delete ... :test #'eq), but only for lists.

Almost always used as (delq nil ...).

[View source](lists.lisp#L101)

### `(mapply fn list &rest lists)`

`mapply` is a cousin of `mapcar`.

If you think of `mapcar` as using `funcall`:

    (mapcar #'- '(1 2 3))
    ≅ (loop for item in '(1 2 3)
            collect (funcall #'- item))

Then `mapply` does the same thing, but with `apply` instead.

    (loop for item in '((1 2 3) (4 5 6))
            collect (apply #'+ item))
    => (6 15)

    (mapply #'+ '((1 2 3) (4 5 6)))
    => (6 15)

In variadic use, `mapply` acts as if `append` had first been used:

    (mapply #'+ xs ys)
    ≡ (mapply #'+ (mapcar #'append xs ys))

But the actual implementation is more efficient.

`mapply` can convert a list of two-element lists into an alist:

    (mapply #'cons '((x 1) (y 2))
    => '((x . 1) (y . 2))

[View source](lists.lisp#L118)

### `(assocdr item alist &rest args &key &allow-other-keys)`

Like (cdr (assoc ...))

[View source](lists.lisp#L172)

### `(assocadr item alist &rest args &key &allow-other-keys)`

Like `assocdr` for alists of proper lists.

     (assocdr 'x '((x 1))) => '(1)
     (assocadr 'x '((x 1))) => 1

[View source](lists.lisp#L177)

### `(rassocar item alist &rest args &key &allow-other-keys)`

Like (car (rassoc ...))

[View source](lists.lisp#L185)

### `(firstn n list)`

The first N elements of LIST, as a fresh list:

    (firstn 4 (iota 10))
    => (0 1 2 4)

(I do not why this extremely useful function did not make it into
Common Lisp, unless it was deliberately left out as an exercise for
Maclisp users.)

[View source](lists.lisp#L190)

### `(powerset set)`

Return the powerset of SET.
Uses a non-recursive algorithm.

[View source](lists.lisp#L202)

### `(efface item list)`

Destructively remove only the first occurence of ITEM in LIST.

From Lisp 1.5.

[View source](lists.lisp#L213)

### `(pop-assoc key alist &rest args)`

Like `assoc` but, if there was a match, delete it from ALIST.

From Newlisp.

[View source](lists.lisp#L232)

### `(mapcar-into fn list)`

Like (map-into list fn list).

From PAIP.

[View source](lists.lisp#L248)

### `(nthrest n list)`

Alias for `nthcdr`.

[View source](lists.lisp#L257)

### `(plist-keys plist)`

Return the keys of a plist.

[View source](lists.lisp#L261)

### `(plist-values plist)`

Return the values of a plist.

[View source](lists.lisp#L267)

## Sequences

### `(do-each (var seq &optional return) &body body)`

Iterate over the elements of SEQ, a sequence.
If SEQ is a list, this is equivalent to `dolist`.

[View source](sequences.lisp#L89)

### `(nsubseq seq start &optional end)`

Return a subsequence that may share structure with SEQ.

Note that `nsubseq` gets its aposematic leading `n` not because it is
itself destructive, but because, unlike `subseq`, destructive
operations on the subsequence returned may mutate the original.

`nsubseq` also works with `setf`, with the same behavior as
`replace`.

[View source](sequences.lisp#L202)

### `(filter pred seq &rest args &key count &allow-other-keys)`

Almost, but not quite, an alias for `remove-if-not`.

The difference is the handling of COUNT: for `filter`, COUNT is the
number of items to *keep*, not remove.

     (remove-if-not #'oddp '(1 2 3 4 5) :count 2)
     => '(1 3 5)

     (filter #'oddp '(1 2 3 4 5) :count 2)
     => '(1 3)

[View source](sequences.lisp#L256)

### `(filterf g pred &rest args)`

Modify-macro for FILTER.
The place designed by the first argument is set to th result of
calling FILTER with PRED, the place, and ARGS.

[View source](sequences.lisp#L285)

### `(keep item seq &rest args &key test from-end key count &allow-other-keys)`

Almost, but not quite, an alias for `remove` with `:test-not` instead of `:test`.

The difference is the handling of COUNT. For keep, COUNT is the number of items to keep, not remove.

     (remove 'x '(x y x y x y) :count 2)
     => '(y y x y)

     (keep 'x '(x y x y x y) :count 2)
     => '(x x)

`keep` becomes useful with the KEY argument:

     (keep 'x ((x 1) (y 2) (x 3)) :key #'car)
     => '((x 1) (x 3))

[View source](sequences.lisp#L291)

### `(single seq)`

Is SEQ a sequence of one element?

[View source](sequences.lisp#L326)

### `(partition pred seq &key start end key)`

Partition elements of SEQ into those for which PRED returns true
and false.

Return two values, one with each sequence.

Exactly equivalent to:
     (values (remove-if-not predicate seq) (remove-if predicate seq))
except it visits each element only once.

Note that `partition` is not just `assort` with an up-or-down
predicate. `assort` returns its groupings in the order they occur in
the sequence; `partition` always returns the “true” elements first.

    (assort '(1 2 3) :key #'evenp) => ((1 3) (2))
    (partition #'evenp '(1 2 3)) => (2), (1 3)

[View source](sequences.lisp#L332)

### `(partitions preds seq &key start end key)`

Generalized version of PARTITION.

PREDS is a list of predicates. For each predicate, `partitions`
returns a filtered copy of SEQ. As a second value, it returns an extra
sequence of the items that do not match any predicate.

Items are assigned to the first predicate they match.

[View source](sequences.lisp#L357)

### `(assort seq &key key test start end)`

Return SEQ assorted by KEY.

     (assort (iota 10)
             :key (lambda (n) (mod n 3)))
     => '((0 3 6 9) (1 4 7) (2 5 8))

You can think of `assort` as being akin to `remove-duplicates`:

     (mapcar #'first (assort list))
     ≡ (remove-duplicates list :from-end t)

[View source](sequences.lisp#L380)

### `(runs seq &key start end key test)`

Return a list of runs of similar elements in SEQ.
The arguments START, END, and KEY are as for `reduce`.

    (runs '(head tail head head tail))
    => '((head) (tail) (head head) (tail))

[View source](sequences.lisp#L428)

### `(batches seq n &key start end even)`

Return SEQ in batches of N elements.

    (batches (iota 11) 2)
    => ((0 1) (2 3) (4 5) (6 7) (8 9) (10))

If EVEN is non-nil, then SEQ must be evenly divisible into batches of
size N, with no leftovers.

[View source](sequences.lisp#L453)

### `(frequencies seq &rest hash-table-args &key key &allow-other-keys)`

Return a hash table with the count of each unique item in SEQ.
As a second value, return the length of SEQ.

From Clojure.

[View source](sequences.lisp#L510)

### `(scan fn seq &key key initial-value)`

A version of `reduce` that shows its work.

Instead of returning just the final result, `scan` returns a sequence
of the successive results at each step.

    (reduce #'+ '(1 2 3 4))
    => 10

    (scan #'+ '(1 2 3 4))
    => '(1 3 6 10)

From APL and descendants.

[View source](sequences.lisp#L535)

### `(nub seq &rest args &key start end key test)`

Remove duplicates from SEQ, starting from the end.
TEST defaults to `equal`.

From Haskell.

[View source](sequences.lisp#L561)

### `(gcp seqs &key test)`

The greatest common prefix of SEQS.

If there is no common prefix, return NIL.

[View source](sequences.lisp#L572)

### `(gcs seqs &key test)`

The greatest common suffix of SEQS.

If there is no common suffix, return NIL.

[View source](sequences.lisp#L589)

### `(of-length length)`

Return a predicate that returns T when called on a sequence of
length LENGTH.

    (funcall (of-length 3) '(1 2 3)) => t
    (funcall (of-length 1) '(1 2 3)) => nil

[View source](sequences.lisp#L608)

### `(length< &rest seqs)`

Is each length-designator in SEQS shorter than the next?
A length designator may be a sequence or an integer.

[View source](sequences.lisp#L623)

### `(length> &rest seqs)`

Is each length-designator in SEQS longer than the next?
A length designator may be a sequence or an integer.

[View source](sequences.lisp#L629)

### `(length>= &rest seqs)`

Is each length-designator in SEQS longer or as long as the next?
A length designator may be a sequence or an integer.

[View source](sequences.lisp#L655)

### `(length<= &rest seqs)`

Is each length-designator in SEQS as long or shorter than the next?
A length designator may be a sequence or an integer.

[View source](sequences.lisp#L660)

### `(longer x y)`

Return the longer of X and Y.

If X and Y are of equal length, return X.

[View source](sequences.lisp#L665)

### `(longest seqs)`

Return the longest seq in SEQS.

[View source](sequences.lisp#L690)

### `(slice seq start &optional end)`

Like `subseq`, but allows negative bounds to specify offsets.
Both START and END accept negative bounds.

     (slice "string" -3 -1) => "in"

Setf of `slice` is like setf of `ldb`: afterwards, the place being set
holds a new sequence which is not EQ to the old.

[View source](sequences.lisp#L719)

### `(ordering seq &key unordered-to-end from-end test key)`

Given a sequence, return a function that, when called with `sort`,
restores the original order of the sequence.

That is, for any SEQ (without duplicates), it is always true that

     (equal seq (sort (reshuffle seq) (ordering seq)))

FROM-END controls what to do in case of duplicates. If FROM-END is
true, the last occurrence of each item is preserved; otherwise, only
the first occurrence counts.

TEST controls identity; it should be a valid test for a hash table. If
the items cannot be compared that way, you can use KEY to transform
them.

UNORDERED-TO-END controls where to sort items that are not present in
the original ordering. By default they are sorted first but, if
UNORDERED-TO-END is true, they are sorted last. In either case, they
are left in no particular order.

[View source](sequences.lisp#L753)

### `(take n seq)`

Return, at most, the first N elements of SEQ, as a *new* sequence
of the same type as SEQ.

If N is longer than SEQ, SEQ is simply copied.

If N is negative, then |N| elements are taken (in their original
order) from the end of SEQ.

[View source](sequences.lisp#L795)

### `(drop n seq)`

Return all but the first N elements of SEQ.
The sequence returned is a new sequence of the same type as SEQ.

If N is greater than the length of SEQ, returns an empty sequence of
the same type.

If N is negative, then |N| elements are dropped from the end of SEQ.

[View source](sequences.lisp#L813)

### `(take-while pred seq)`

Return the prefix of SEQ for which PRED returns true.

[View source](sequences.lisp#L831)

### `(drop-while pred seq)`

Return the largest possible suffix of SEQ for which PRED returns
false when called on the first element.

[View source](sequences.lisp#L838)

### `(bestn n seq pred &key key memo)`

Partial sorting.
Equivalent to (firstn N (sort SEQ PRED)), but much faster, at least
for small values of N.

With MEMO, use a decorate-sort-undecorate transform to ensure KEY is
only ever called once per element.

The name is from Arc.

[View source](sequences.lisp#L943)

### `(nth-best n seq pred &key key)`

Return the Nth-best element of SEQ under PRED.

Equivalent to

    (elt (sort (copy-seq seq) pred) n)

Or even

    (elt (bestn (1+ n) seq pred) n)

But uses a selection algorithm for better performance than either.

[View source](sequences.lisp#L990)

### `(reshuffle seq &key element-type)`

Like `alexandria:shuffle`, but non-destructive.

Regardless of the type of SEQ, the return value is always a vector.

If ELEMENT-TYPE is provided, this is the element type (modulo
upgrading) of the vector returned.

If ELEMENT-TYPE is not provided, then the element type of the vector
returned is T, if SEQ is not a vector. If SEQ is a vector, then the
element type of the vector returned is the same as the as the element
type of SEQ.

[View source](sequences.lisp#L1037)

### `(sort-new seq pred &key key element-type)`

Return a sorted vector of the elements of SEQ.

You can think of this as a non-destructive version of `sort`, except
that it always returns a vector. (If you're going to copy a sequence
for the express purpose of sorting it, you might as well copy it into
a form that can be sorted efficiently.)

ELEMENT-TYPE is interpreted as for `reshuffle`.

[View source](sequences.lisp#L1057)

### `(stable-sort-new seq pred &key key element-type)`

Like `sort-new`, but sort as if by `stable-sort` instead of `sort`.

[View source](sequences.lisp#L1077)

### `(extrema seq pred &key key start end)`

Like EXTREMUM, but returns both the minimum and the maximum (as two
values).

     (extremum (iota 10) #'>) => 9
     (extrema (iota 10) #'>) => 9, 0

[View source](sequences.lisp#L1084)

### `(halves seq &optional split)`

Return, as two values, the first and second halves of SEQ.
SPLIT designates where to split SEQ; it defaults to half the length,
but can be specified.

If SPLIT is not provided, the length is halved using `ceiling` rather
than `truncate`. This is on the theory that, if SEQ is a
single-element list, it should be returned unchanged.

If SPLIT is negative, then the split is determined by counting |split|
elements from the right (or, equivalently, length+split elements from
the left.

[View source](sequences.lisp#L1125)

### `(dsu-sort seq fn &key key stable)`

Decorate-sort-undecorate using KEY.
Useful when KEY is an expensive function (e.g. database access).

[View source](sequences.lisp#L1159)

### `(deltas seq &optional fn)`

Return the successive differences in SEQ.

     (deltas '(4 9 -5 1 2))
     => '(4 5 -14 6 1)

Note that the first element of SEQ is also the first element of the
return value.

By default, the delta is the difference, but you can specify another
function as a second argument:

    (deltas '(2 4 2 6) #'/)
    => '(2 2 1/2 3)

From Q.

[View source](sequences.lisp#L1174)

### `(inconsistent-graph-constraints inconsistent-graph)`

The constraints of an `inconsistent-graph` error.
Cf. `toposort`.

[View source](sequences.lisp#L1198)

### `(toposort constraints &key test tie-breaker from-end unordered-to-end)`

Turn CONSTRAINTS into a predicate for use with SORT.

Each constraint should be two-element list, where the first element of
the list should come before the second element of the list.

    (def dem-bones '((toe foot)
                     (foot heel)
                     (heel ankle)
                     (ankle shin)
                     (shin knee)
                     (knee back)
                     (back shoulder)
                     (shoulder neck)
                     (neck head)))
    (sort (reshuffle (mapcar #'car dem-bones))
          (toposort dem-bones))
    => (TOE FOOT HEEL ANKLE SHIN KNEE BACK SHOULDER NECK)

If the graph is inconsistent, signals an error of type
`inconsistent-graph`:

    (toposort '((chicken egg) (egg chicken)))
    => Inconsistent graph: ((CHICKEN EGG) (EGG CHICKEN))

TEST, FROM-END, and UNORDERED-TO-END are passed through to
`ordering`.

[View source](sequences.lisp#L1235)

### `(intersperse new-elt seq)`

Return a sequence like SEQ, but with NEW-ELT inserted between each
element.

[View source](sequences.lisp#L1295)

### `(mvfold fn seq &rest seeds)`

Like `reduce` extended to multiple values.

Calling `mvfold` with one seed is equivalent to `reduce`:

    (mvfold fn xs seed) ≡ (reduce fn xs :initial-value seed)

However, you can also call `mvfold` with multiple seeds:

    (mvfold fn xs seed1 seed2 seed3 ...)

How is this useful? Consider extracting the minimum of a sequence:

    (reduce #'min xs)

Or the maximum:

    (reduce #'max xs)

But both?

    (reduce (lambda (cons item)
              (cons (min (car cons) item)
                    (max (cdr cons) item)))
            xs
            :initial-value (cons (elt xs 0) (elt xs 0)))

You can do this naturally with `mvfold`.

    (mvfold (lambda (min max item)
              (values (min item min)
                      (max item max)))
            xs (elt xs 0) (elt xs 0))

In general `mvfold` provides a functional idiom for “loops with
book-keeping” where we might otherwise have to use recursion or
explicit iteration.

Has a compiler macro that generates efficient code when the number of
SEEDS is fixed at compile time (as it usually is).

[View source](sequences.lisp#L1324)

### `(mvfoldr fn seq &rest seeds)`

Like `(reduce FN SEQ :from-end t)' extended to multiple
values. Cf. `mvfold`.

[View source](sequences.lisp#L1366)

### `(repeat-sequence seq n)`

Return a sequence like SEQ, with the same content, but repeated N times.

    (repeat-sequence "13" 3)
    => "131313"

The length of the sequence returned will always be the length of SEQ
times N.

This means that 0 repetitions results in an empty sequence:

    (repeat-sequence "13" 0)
    => ""

Conversely, N may be greater than the possible length of a sequence,
as long as SEQ is empty.

    (repeat-sequence "" (1+ array-dimension-limit))
    => ""


[View source](sequences.lisp#L1406)

### `(seq= &rest xs)`

Like `equal`, but recursively compare sequences element-by-element.

Two elements X and Y are `seq=` if they are `equal`, or if they are
both sequences of the same length and their elements are all `seq=`.

[View source](sequences.lisp#L1471)

## Strings

### `(whitespacep char)`

Is CHAR whitespace?

Spaces, tabs, any kind of line break, page breaks, and no-break spaces
are considered whitespace.

[View source](strings.lisp#L16)

### `(trim-whitespace string)`

STRING without whitespace at ends.

[View source](strings.lisp#L24)

### `(ascii-char-p char)`

Is CHAR an ASCII char?

[View source](strings.lisp#L28)

### `(with-string (var &optional stream) &body body)`

Bind VAR to the character stream designated by STREAM.

STREAM is resolved like the DESTINATION argument to `format`: it can
be any of t (for `*standard-output*`), nil (for a string stream), a
string with a fill pointer, or a stream to be used directly.

When possible, it is a good idea for functions that build strings to
take a stream to write to, so callers can avoid consing a string just
to write it to a stream. This macro makes it easy to write such
functions.

    (defun format-x (x &key stream)
      (with-string (s stream)
        ...))

[View source](strings.lisp#L46)

### `(collapse-whitespace string)`

Collapse runs of whitespace in STRING.
Each run of space, newline, and other whitespace characters is
replaced by a single space character.

[View source](strings.lisp#L75)

### `(blankp seq)`

SEQ is either empty, or consists entirely of characters that
satisfy `whitespacep`.

[View source](strings.lisp#L95)

### `(concat &rest strings)`

Abbreviation for (concatenate 'string ...).

From Emacs Lisp.

[View source](strings.lisp#L109)

### `(mapconcat fun seq separator &key stream)`

Build a string by mapping FUN over SEQ.
Separate each value with SEPARATOR.

Equivalent to
        (reduce #'concat (intersperse SEP SEQ) :key FUN)
but more efficient.

STREAM can be used to specify a stream to write to. It is resolved
like the first argument to `format`.

From Emacs Lisp.

[View source](strings.lisp#L134)

### `(string-join strings &optional separator)`

Like `(mapconcat #'string STRINGS (string SEPARATOR))'.

[View source](strings.lisp#L156)

### `(string-upcase-initials string)`

Return STRING with the first letter of each word capitalized.
This differs from STRING-CAPITALIZE in that the other characters in
each word are not changed.

     (string-capitalize "an ACRONYM") -> "An Acronym")
     (string-upcase-initials "an ACRONYM") -> "An ACRONYM")

From Emacs Lisp (where it is simply `upcase-initials`).

[View source](strings.lisp#L161)

### `(nstring-upcase-initials string)`

Destructive version of `string-upcase-initials`.

[View source](strings.lisp#L173)

### `(same-case-p string)`

Every character with case in STRING has the same case.
Return `:upper` or `:lower` as appropriate.

[View source](strings.lisp#L193)

### `(nstring-invert-case string)`

Destructive version of `string-invert-case`.

[View source](strings.lisp#L216)

### `(string-invert-case string)`

Invert the case of STRING.
This does the same thing as a case-inverting readtable.

[View source](strings.lisp#L225)

### `(words string &key start end)`

Split STRING into words.

The definition of a word is the same as that used by
`string-capitalize`: a run of alphanumeric characters.

    (words "Four score and seven years")
    => ("Four" "score" "and" "seven" "years")

    (words "2 words")
    => ("2" "words")

    (words "two_words")
    => ("two" "words")

    (words "\"I'm here,\" Tom said presently.")
    => ("I" "m" "here" "Tom" "said" "presently")

Cf. `tokens`.

[View source](strings.lisp#L232)

### `(tokens string &key start end)`

Separate STRING into tokens.
Tokens are runs of non-whitespace characters.

    (tokens "\"I'm here,\" Tom said presently.")
    => ("\"I'm" "here,\"" "Tom" "said" "presently.")

Cf. `words`.

[View source](strings.lisp#L262)

### `(word-wrap string &key column stream)`

Return a word-wrapped version of STRING that breaks at COLUMN.

Note that this is not a general-purpose word-wrapping routine like you
would find in a text editor: in particular, any existing whitespace is
removed.

[View source](strings.lisp#L277)

### `(lines string)`

A list of lines in STRING.

[View source](strings.lisp#L309)

### `(fmt control-string &rest args)`

A cousin of `format` expressly for fast formatting of strings.

Like (format nil ...), binding `*pretty-pretty*` to `nil`, which in
some Lisps means a significant increase in speed.

Has a compiler macro with `formatter`.

[View source](strings.lisp#L315)

### `(escape string table &key start end stream)`

Write STRING to STREAM, escaping with TABLE.

TABLE should be either a hash table, with characters for keys and
strings for values, or a function that takes a character and
returns (only) either a string or null.

That is, the signature of TABLE should be:

    (function (character) (or string null))

where `nil` means to pass the character through unchanged.

STREAM can be used to specify a stream to write to, like the first
argument to `format`. The default behavior, with no stream specified,
is to return a string.

[View source](strings.lisp#L356)

### `(ellipsize string n &key ellipsis)`

If STRING is longer than N, truncate it and append ELLIPSIS.

Note that the resulting string is longer than N by the length of
ELLIPSIS, so if N is very small the string may come out longer than it
started.

     (ellipsize "abc" 2)
     => "ab..."

From Arc.

[View source](strings.lisp#L402)

### `(string-prefix-p prefix string &key start1 end1 start2 end2)`

Like `string^=`, but case-insensitive.

[View source](strings.lisp#L442)

### `(string^= prefix string &key start1 end1 start2 end2)`

Is PREFIX a prefix of STRING?

[View source](strings.lisp#L442)

### `(string$= suffix string &key start1 end1 start2 end2)`

Is SUFFIX a suffix of STRING?

[View source](strings.lisp#L462)

### `(string-suffix-p suffix string &key start1 end1 start2 end2)`

Like `string$=`, but case-insensitive.

[View source](strings.lisp#L462)

### `(string-contains-p substring string &key start1 end1 start2 end2)`

Like `string*=`, but case-insensitive.

[View source](strings.lisp#L482)

### `(string*= substring string &key start1 end1 start2 end2)`

Is SUBSTRING a substring of STRING?

This is similar, but not identical, to SEARCH.

     (search nil "foo") => 0
     (search "nil" "nil") => 0
     (string*= nil "foo") => NIL
     (string*= nil "nil") => T

[View source](strings.lisp#L482)

### `(string~= token string &key start1 end1 start2 end2)`

Does TOKEN occur in STRING as a token?

Equivalent to
     (find TOKEN (tokens STRING) :test #'string=),
but without consing.

[View source](strings.lisp#L504)

### `(string-token-p token string &key start1 end1 start2 end2)`

Like `string~=`, but case-insensitive.

[View source](strings.lisp#L504)

### `(string-replace old string new &key start end stream)`

Like `string-replace-all`, but only replace the first match.

[View source](strings.lisp#L528)

### `(string-replace-all old string new &key start end stream count)`

Do search-and-replace for constant strings.

Note that START and END only affect where the replacements are made:
the part of the string before START, and the part after END, are
always included verbatim.

     (string-replace-all "old" "The old old way" "new"
                         :start 3 :end 6)
     => "The new old way"

COUNT can be used to limit the maximum number of occurrences to
replace. If COUNT is not specified, every occurrence of OLD between
START and END is replaced with NEW.

    (string-replace-all "foo" "foo foo foo" "quux")
    => "quux quux quux"

    (string-replace-all "foo" "foo foo foo" "quux" :count 2)
    => "quux quux foo"

STREAM can be used to specify a stream to write to. It is resolved
like the first argument to `format`.

[View source](strings.lisp#L536)

### `(chomp string &optional suffixes)`

If STRING ends in one of SUFFIXES, remove that suffix.

SUFFIXES defaults to a Lisp newline, a literal line feed, a literal
carriage return, or a literal carriage return followed by a literal
line feed.

Takes care that the longest suffix is always removed first.

[View source](strings.lisp#L601)

### `(string-count substring string &key start end)`

Count how many times SUBSTRING appears in STRING.

[View source](strings.lisp#L630)

### `(string+ &rest args)`

Optimized function for building small strings.

Roughly equivalent to

    (let ((*print-pretty* nil))
     (format nil "~@{~a}" args...))

But with a compiler macro that can sometimes result in more efficient
code.

[View source](strings.lisp#L649)

## Vectors

### `(vect &rest initial-contents)`

Succinct constructor for adjustable vectors with fill pointers.

    (vect 1 2 3)
    ≡ (make-array 3
            :adjustable t
            :fill-pointer 3
            :initial-contents (list 1 2 3))

The fill pointer is placed after the last element in INITIAL-CONTENTS.

[View source](vectors.lisp#L4)

### `(vector= v1 v2 &key test start1 end1 start2 end2)`

Like `string=` for any vector.

[View source](vectors.lisp#L56)

## Internal Definitions

### `(local* &body body)`

Like `local`, but leave the last form in BODY intact.

     (local*
       (defun aux-fn ...)
       (defun entry-point ...))
     =>
     (labels ((aux-fn ...))
       (defun entry-point ...)) 

[View source](internal-definitions.lisp#L23)

### `(local &body orig-body)`

Make internal definitions using top-level definition forms.

Within `local` you can use top-level definition forms and have them
create purely local definitions, like `let`, `labels`, and `macrolet`:

     (fboundp 'plus) ; => nil

     (local
       (defun plus (x y)
         (+ x y))
       (plus 2 2))
     ;; => 4

     (fboundp 'plus) ; => nil

Each form in BODY is subjected to partial expansion (with
`macroexpand-1`) until either it expands into a recognized definition
form (like `defun`) or it can be expanded no further.

(This means that you can use macros that expand into top-level
definition forms to create local definitions.)

Just as at the real top level, a form that expands into `progn` (or an
equivalent `eval-when`) is descended into, and definitions that occur
within it are treated as top-level definitions.

(Support for `eval-when` is incomplete: `eval-when` is supported only
when it is equivalent to `progn`).

The recognized definition forms are:

- `def`, for lexical variables (as with `letrec`)
- `define-values`, for multiple lexical variables at once
- `defun`, for local functions (as with `labels`)
- `defalias`, to bind values in the function namespace (like `fbindrec*`)
- `declaim`, to make declarations (as with `declare`)
- `defconstant` and `defconst`, which behave exactly like symbol macros
- `define-symbol-macro`, to bind symbol macros (as with `symbol-macrolet`)

Also, with serious restrictions, you can use:

- `defmacro`, for local macros (as with `macrolet`)

(Note that the top-level definition forms defined by Common Lisp
are (necessarily) supplemented by three from Serapeum: `def',
`define-values`, and `defalias`.)

The exact order in which the bindings are made depends on how `local`
is implemented at the time you read this. The only guarantees are that
variables are bound sequentially; functions can always close over the
bindings of variables, and over other functions; and macros can be
used once they are defined.

     (local
       (def x 1)
       (def y (1+ x))
       y)
     => 2

     (local
       (defun adder (y)
         (+ x y))
       (def x 2)
       (adder 1))
     => 3

Perhaps surprisingly, `let` forms (as well as `let*` and
`multiple-value-bind`) *are* descended into; the only difference is
that `defun` is implicitly translated into `defalias`. This means you
can use the top-level idiom of wrapping `let` around `defun`.

    (local
      (let ((x 2))
        (defun adder (y)
          (+ x y)))
      (adder 2))
    => 4

Support for macros is sharply limited. (Symbol macros, on the other
hand, are completely supported.)

1. Macros defined with `defmacro` must precede all other expressions.

2. Macros cannot be defined inside of binding forms like `let`.

3. `macrolet` is not allowed at the top level of a `local` form.

These restrictions are undesirable, but well justified: it is
impossible to handle the general case both correctly and portably, and
while some special cases could be provided for, the cost in complexity
of implementation and maintenance would be prohibitive.

The value returned by the `local` form is that of the last form in
BODY. Note that definitions have return values in `local` just like
they do at the top level. For example:

     (local
       (plus 2 2)
       (defun plus (x y)
         (+ x y)))

Returns `plus`, not 4.

The `local` macro is loosely based on Racket's support for internal
definitions.

[View source](internal-definitions.lisp#L662)

### `(block-compile (&key entry-points (block-compile t)) &body body)`

Shorthand for block compilation with `local*`.

Only the functions in ENTRY-POINTS will have global definitions. All
other functions in BODY will be compiled as purely local functions,
and all of their calls to one another will be compiled as local calls.
This includes calls to the entry points, and even self-calls from
within the entry points.

If you pass `:block-compile nil', this macro is equivalent to progn.
This may be useful during development.

[View source](internal-definitions.lisp#L777)

## Tree Case

### `(tree-case keyform &body cases)`

A variant of `case` optimized for when every key is an integer.

Comparison is done using `eql`.

[View source](tree-case.lisp#L8)

### `(tree-ecase keyform &body clauses)`

Like `tree-case`, but signals an error if KEYFORM does not match
any of the provided cases.

[View source](tree-case.lisp#L34)

### `(char-case keyform &body clauses)`

Like `case`, but specifically for characters.
Expands into `tree-case`.

As an extension to the generalized `case` syntax, the keys of a clause
can be specified as a literal string.

    (defun vowel? (c)
      (char-case c
        ("aeiouy" t)))

Signals an error if KEYFORM does not evaluate to a character.

[View source](tree-case.lisp#L47)

### `(char-ecase keyform &body clauses)`

Like `ecase`, but specifically for characters.
Expands into `tree-case`.

[View source](tree-case.lisp#L62)

## Dispatch Case

### `(dispatch-case (&rest exprs-and-types) &body clauses)`

Dispatch on the types of multiple expressions, exhaustively.

Say you are working on a project where you need to handle timestamps
represented both as universal times, and as instances of
`local-time:timestamp`. You start by defining the appropriate types:

    (defpackage :dispatch-case-example
      (:use :cl :alexandria :serapeum :local-time)
      (:shadow :time))
    (in-package :dispatch-case-example)

    (deftype universal-time ()
      '(integer 0 *))

    (deftype time ()
      '(or universal-time timestamp))

Now you want to write a `time=` function that works on universal
times, timestamps, and any combination thereof.

You can do this using `etypecase-of`:

    (defun time= (t1 t2)
      (etypecase-of time t1
        (universal-time
         (etypecase-of time t2
           (universal-time
            (= t1 t2))
           (timestamp
            (= t1 (timestamp-to-universal t2)))))
        (timestamp
         (etypecase-of time t2
           (universal-time
            (time= t2 t1))
           (timestamp
            (timestamp= t1 t2))))))

This has the advantage of efficiency and exhaustiveness checking, but
the serious disadvantage of being hard to read: to understand what
each branch matches, you have to backtrack to the enclosing branch.
This is bad enough when the nesting is only two layers deep.

Alternately, you could do it with `defgeneric`:

    (defgeneric time= (t1 t2)
      (:method ((t1 integer) (t2 integer))
        (= t1 t2))
      (:method ((t1 timestamp) (t2 timestamp))
        (timestamp= t1 t2))
      (:method ((t1 integer) (t2 timestamp))
        (= t1 (timestamp-to-universal t2)))
      (:method ((t1 timestamp) (t2 integer))
        (time= t2 t1)))

This is easy to read, but it has three disadvantages. (1) There is no
exhaustiveness checking. If, at some point in the future, you want to
add another representation of time to your project, the compiler will
not warn you if you forget to update `time=`. (This is bad enough with
only two objects to dispatch on, but with three or more it gets
rapidly easier to miss a case.) (2) You cannot use the
`universal-time` type you just defined; it is a type, not a class, so
you cannot specialize methods on it. (3) You are paying a run-time
price for extensibility -- the inherent overhead of a generic function
-- when extensibility is not what you want.

Using `dispatch-case` instead gives you the readability of
`defgeneric` with the efficiency and safety of `etypecase-of`.

    (defun time= (t1 t2)
      (dispatch-case ((time t1)
                      (time t2))
        ((universal-time universal-time)
         (= t1 t2))
        ((timestamp timestamp)
         (timestamp= t1 t2))
        ((universal-time timestamp)
         (= t1 (timestamp-to-universal t2)))
        ((timestamp universal-time)
         (time= t2 t1))))

The syntax of `dispatch-case` is much closer to `defgeneric` than it
is to `etypecase`. The order in which clauses are defined does not
matter, and you can define fallthrough clauses in the same way you
would define fallthrough methods in `defgeneric`.

Suppose you wanted to write a `time=` function like the one above, but
always convert times to timestamps before comparing them. You could
write that using `dispatch-case` like so:

    (defun time= (x y)
      (dispatch-case ((x time)
                      (y time))
        ((time universal-time)
         (time= x (universal-to-timestamp y)))
        ((universal-time time)
         (time= (universal-to-timestamp x) y))
        ((timestamp timestamp)
         (timestamp= x y))))

Note that this requires only three clauses, where writing it out using
nested `etypecase-of` forms would require four clauses. This is a
small gain; but with more subtypes to dispatch on, or more objects,
such fallthrough clauses become more useful.

[View source](dispatch-case.lisp#L95)

### `(dispatch-case-let (&rest bindings) &body clauses)`

Like `dispatch-case`, but establish new bindings for each expression.

For example,

    (dispatch-case-let (((x string) (expr1))
                        ((y string) (expr2)))
      ...)

is equivalent to

    (let ((x (expr1))
          (y (expr2)))
      (dispatch-case ((x string)
                      (y string))
        ...))

It may be helpful to think of this as a cross between
`defmethod` (where the (variable type) notation is used in the lambda
list) and `let` (which has an obvious macro-expansion in terms of
`lambda`).

[View source](dispatch-case.lisp#L207)

## Range

A possibly over-engineered `range` function. Why is it worth all the
fuss? It's used extensively in Serapeum's test suite. The faster
`range` runs, and the less pressure it puts on the garbage collector,
the faster the test suite runs.

[range]: https://docs.python.org/2/library/functions.html#range


### `(range start &optional stop step)`

Return a (possibly specialized) vector of real numbers, starting from START.

With three arguments, return the integers in the interval [start,end)
whose difference from START is divisible by STEP.

START, STOP, and STEP can be any real number, except that if STOP is
greater than START, STEP must be positive, and if START is greater
than STOP, STEP must be negative.

The vector returned has the smallest element type that can represent
numbers in the given range. E.g. the range [0,256) will usually be
represented by a vector of octets, while the range [-10.0,10.0) will
be represented by a vector of single floats. The exact representation,
however, depends on your Lisp implementation.

STEP defaults to 1.

With two arguments, return all the steps in the interval [start,end).

With one argument, return all the steps in the interval [0,end).

[View source](range.lisp#L214)

