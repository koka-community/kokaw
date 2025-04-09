/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
import std/os/env
import std/os/path
import std/os/process
import kokac/kokac
import kokac/package
import kokac/git
import kokac/utils

pub fun main()
  val args = get-args()
  match args
    Cons("init", Cons(name, Nil)) -> init(name.path)
    Cons("init", Nil) -> init()
    _ ->
      val file = args.filter(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
      match file
        Cons(f, Nil) -> 
          val root = find-package-root(f.path.realpath)
          run-system(root.realpath.string ++ " " ++ args.join(" "))
          ()
        _ -> throw("Pass a file to resolve the package location from, even for the language server")