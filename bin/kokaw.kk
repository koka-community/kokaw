/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
import std/os/env
import std/os/path
import std/os/dir
import std/os/process
import kokaw/kokaw
import kokaw/package
import kokaw/git
import kokaw/utils

pub fun main()
  val args = get-args()
  match args
    Cons("init", Cons(name, Nil)) -> init(name.path)
    Cons("init", Nil) -> init()