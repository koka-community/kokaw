/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokaw/package
import std/os/path
import kokaw/git
import std/os/flags

// compiler: default // if default is specified then the one from the system path is used
//   path: ... (a path to the koka SDK directory -- the Koka executable will be discovered via stack)
//   commit: ... (a specific version of the koka compiler to checkout (shallowly) in a hash referenced location and compiled via `stack build`)
//   version: ... (ensures the version is downloaded to some known location, but not installed globally, so there can be multiple simultaneous versions)
pub type compiler
  Default
  Sdk(sdk-path: path) 
  Commit(hash: string)
  Version(version: string)

// Package cache resolution (currently defaults to local)
pub type resolution
  // Global cache for the user, configure using
  // `global-package-cache(path)` 
  // (path defaults to `XDG_DATA_DIR/.kokaw`)
  Global(pkg-path: path)
  // Cache dependencies relative to the package.yaml
  // Make sure to .gitignore the `deps/` folder
  // `local-package-cache()`
  Local 

pub fun resolution/(==)(r1: resolution, r2: resolution): bool
  match (r1, r2)
    (Global(pkg-path1), Global(pkg-path2)) -> pkg-path1.string == pkg-path2.string
    (Local, Local) -> True
    (_, _) -> False

// Automatically generated.
// Shows a string representation of the `resolution` type.
pub fun resolution/show(this : resolution) : e string
  match this
    Global(pkg-path) ->
      "Global(pkg-path: " ++ show(pkg-path) ++ ")"
    Local ->
      "Local"

// Currently the only source of a dependency can be a git ref.
pub type dep-source
  GitDep(url: string, path: string, commit: git-ref)

pub fun dep-source/(==)(d1: dep-source, d2: dep-source): bool
  match (d1, d2)
    (GitDep(url1, path1, commit1), GitDep(url2, path2, commit2)) ->
      url1 == url2 && path1 == path2 && commit1 == commit2

// Automatically generated.
// Shows a string representation of the `dep-source` type.
pub fun dep-source/show(this : dep-source) : e string
  match this
    GitDep(url, path, commit) ->
      "GitDep(url: " ++ url ++ ", path: " ++ path ++ ", commit: " ++ show(commit) ++ ")"

// dependencies
//   name: git.... // or just a url
//   name:
//     git: 
//       url: ...
//       ref: ... (optional) defaults to main
//       path: ... (optional)
// dev_dependencies (used for dependencies used in /bin /test /examples, but not in your main package) if you are not creating a package, and just a binary ignore this
//   name:
//     ....
pub value struct dependency
  name: string
  source: dep-source;

pub fun dependency/(==)(d1: dependency, d2: dependency): bool
  match (d1, d2)
    (Dependency(name1, source1), Dependency(name2, source2)) ->
      name1 == name2 && source1 == source2

// Automatically generated.
// Shows a string representation of the `dependency` type.
pub fun dependency/show(this : dependency) : e string
  match this
    Dependency(name, source) ->
      "Dependency(name: " ++ name ++ ", source: " ++ source.show ++ ")"

// No dependency on community std, means we have to do our own "set" operation - here we are doing it lazily after concatenating lists
pub fun unique(l: list<dependency>): list<dependency>
  var result := []
  l.foreach fn(d)
    if result.any(fn(d1) d.name == d1.name) then
      ()
    else
      result := Cons(d, result)
  result

// scripts
//   script(name)
//     "command" // run an os "command"
//   script(name) fn(args)
//      ... // run a Koka script
//   script(name, flags-default, flags=[...]) fn(parsed-flags, arg)
//      ... // run a Koka script with `std/os/flags` parsed flags

pub type script 
  SimpleScript(
    command: string,
    execute: string
  )
  KokaScript<a>(
    command: string,
    flags: list<flag<a>>,
    default: a,
    execute: (a, list<string>) -> io-noexn int
  )

// Automatically generated.
// Shows a string representation of the `script` type.
pub fun script/show(this : script) : e string
  match this
    SimpleScript(command, execute) ->
      "Script(command: " ++ command ++ ", execute: " ++ execute ++ ")"
    KokaScript(command, flags) ->
      flags.usage("usage:\n ./kokaw run " ++ command ++ " [flags] arguments\n\nflags:")
