# ............................................................................................... #
#
# Copyright 2012-2014 Institut National des Sciences Appliquées de Lyon (INSA-Lyon)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ............................................................................................... #

----
This module defines utility functions and augmentations to ease the use of
the `gololang.LazyList` object.

A lazy list is a *immutable* list that is evaluated only when needed, as can be
found in Haskell for example.

This is very useful when using higher order function such as `map`. Mapping
long a lazy list with a function and using only the 3 first elements will only
apply the function to these elements, as oposed to regular lists.

Lazy lists can also be used to create infinite lists or generators.

Lastly, they allow for elegant recursive implementations of several classical
algorithms.

On the other hand, functions or methods like `equals`, `size` or `contains` are
not very efficients, since they must evaluate the whole list, and thus negate
the lazyness. They are here for completeness and compatibility with the regular
lists interface, but you should avoid such methods.

Some functions in this module are recursive (re)implementation of standard list
HOF, such as `map` or `filter`. The recursive aspect should not be limiting since
the resulting list is lazy.
----
module gololang.lazylist

import java.util

# ............................................................................................... #
# Utils, constructors and conversions

----
Returns the empty list.
----
function emptyList = -> gololang.LazyList.EMPTY()

----
Create a new lazy list from a head and tail values. Automatically wraps the
tail in a closure if its not already one.

For example:

    let myList = cons(1, cons(2, cons(3, emptyList())))

gives a lazy list equivalent to `list[1, 2, 3]`

----
function cons = |head, tail| -> match {
  when isClosure(tail) then gololang.LazyList.cons(head, tail)
  when tail is null then gololang.LazyList.cons(head, ^emptyList)
  otherwise gololang.LazyList.cons(head, -> tail)
}

----
Unary version of [`cons(head, tail)`](#cons_head_tail).

Its parameter is assumed to be a tuple (or any object having a `get(idx)` method)
of the form `[head, tail]`.
----
function cons = |ht| -> cons(ht: get(0), ht: get(1))

----
Variadic function to create lazy lists from values.

    let myList = lazyList(1, 2, 3, 4)

is the equivalent to

    let myList = cons(1, cons(2, cons(3, cons(4, emptyList()))))
----
function lazyList = |values...| -> iteratorToLazyList(values: asList(): iterator())

----
Wraps any object implementing `Iterable` or `Iterator` in a lazy list.
The `next()` method of the underlying iterator is only called when the tail is
used.

NOTE:
If called with an `Iterator` instance, the iterator is shared, so navigating
through the list can have side effects if another object is using the same
iterator.
----
function fromIter = |it| -> match {
  when it oftype Iterable.class then
    iteratorToLazyList(it: iterator())
  when it oftype Iterator.class then
    iteratorToLazyList(it)
  otherwise raise("Invalid argument for fromIter")
}

augment java.lang.Iterable {
  function asLazyList = |this| -> iteratorToLazyList(this: iterator())
}

augment java.util.Iterator {
  function asLazyList = |this| -> iteratorToLazyList(this)
}

local function iteratorToLazyList = |iterator| {
  if not iterator: hasNext() {
    return gololang.LazyList.EMPTY()
  } else {
    let head = iterator: next()
    return gololang.LazyList.cons(head, -> iteratorToLazyList(iterator))
  }
}

# ............................................................................................... #

augment gololang.LazyList {

  ----
  Maps elements of a list using a function:

      lazyList(1, 2, 3):map(|x| -> 2 * x)

  `map` returns a new lazy list, i.e. `func` is applied only
  when necessary.

  This is a recursive implementation.
  ----
  function map = |this, func| -> match {
    when this: isEmpty() then gololang.LazyList.EMPTY()
    otherwise gololang.LazyList.cons(
      func(this: head()), -> this: tail(): map(func)
    )
  }

  ----
  Filters elements based on a predicate.

  Returns a new lazy list.
  ----
  function filter = |this, pred| -> match {
    when this: isEmpty() then gololang.LazyList.EMPTY()
    when pred(this: head()) then
      gololang.LazyList.cons(this: head(), -> this: tail(): filter(pred))
    otherwise this: tail(): filter(pred)
  }

  ----
  Finds the first element of a list matching a predicate:

      println(lazyList(1, 2, 3, 4): find(|n| -> n > 3))

  * `this`: a lazy list.
  * `pred`: a predicate function taking an element and returning a boolean.

  `find` returns `null` when no element satisfies `pred`.

  Note that in the worst case, all the list is search. Take care to **not use**
  this method on infinite list, since no check is made.
  ----
  function find = |this, pred| -> match {
    when this: isEmpty() then null
    when pred(this: head()) then this: head()
    otherwise this: tail(): find(pred)
  }

  ----
  Join the elements into a string:

      println(list[1, 2, 3]: join(", "))

  * `this`: a list.
  * `separator`: the element separator string.

  The returned string is `""` when the list is empty.
  ----
  function join = |this, separator| {
    if this: isEmpty() {
      return ""
    }
    var it = this: iterator()
    var buffer = java.lang.StringBuilder(it: next(): toString())
    while it: hasNext() {
        buffer: append(separator)
        buffer: append(it: next())
    }
    return buffer: toString()
  }

}

----
Generator function on lazy lists.

This function generate a (possibly infinite) lazy list. Starting with the
`seed` value, if `finished(seed)` is `true`, the generation stops and an empty
list is returned. Otherwise, `unspool` is called on `seed`, and must generate
two values: the head of the list (current value) and the next seed that will be
used to generate the tail.

As an example, one can write a simple `range` function as:

    let range = |start, end| -> generator(
      |seed| -> [seed, seed + 1],
      |seed| -> seed >= end,
      start
    )

* `unspool`: the generative function
* `finished`: the condition function
* `seed`: the initial value
----
function generator = |unspool, finished, seed| {
  if finished(seed) {
    return gololang.LazyList.EMPTY()
  }
  let r = unspool(seed)
  return gololang.LazyList.cons(
    r:get(0),
    -> generator(unspool, finished, r:get(1))
  )
}

local function False = |args...| -> false

----
Produces a infinite list of values. If the argument is a closure, it must have
no parameters, and it's used to produce the values (called for each `tail`
access).

For instance, `repeat(5)` will return an infinite lazy list of `5`s, and 
`repeate(^f)` will return a infinte lazy list of calls to `f`
([f(), f(), f(), ...])

* `value`: a value or a closure
----
function repeat = |value| -> match {
  when isClosure(value) then generator(|seed| -> [value(), null], ^False, null)
  otherwise generator(|seed| -> [value, null], ^False, null)
}

----
Returns an infinite lazy list produced by iterative application of a function 
to an initial element.
`iterate(z, f)` thus yield `z, f(z), f(f(z)), ...`

For instance, one can create a infinite list of integers using:
    
    iterate(0, |x| -> x + 1)


* `zero`: the initial element of the list
* `func`: the function to apply
----
function iterate = |zero, func| -> generator(|seed| -> [seed, func(seed)], ^False, zero)

