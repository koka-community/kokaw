/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/package
import std/os/path
import kokac/git

// WIP: Package file format
// ``` koka.yaml
// compiler: default // if default is specified then the one from the system path is used
//   path: ... (a path to the koka SDK directory -- the Koka executable will be discovered via stack)
//   commit: ... (a specific version of the koka compiler to checkout (shallowly) in a hash referenced location and compiled via `stack build`)
//   version: ... (ensures the version is downloaded to some known location, but not installed globally, so there can be multiple simultaneous versions)
// 
// resolution:
//   global: path
//   local // (defaults to local) global resolution stores all packages in a global directory (i.e. koka-community is the default path), local stores it relative to the koka.yaml (in deps/) - make sure to .gitignore
// 
// dependencies:
//   name: git.... // or just a url
//   name:
//     git: 
//       url: ...
//       ref: ... (optional) defaults to main
//       path: ... (optional)
// 
// dev_dependencies: (used for dependencies used in /bin /test /examples, but not in your main package) if you are not creating a package, and just a binary ignore this
//   name:
//     ....
// 
// scripts:
//   name: '...' // a subcommand of kokac to provide quick commands
// ```
pub type compiler
  Default
  Sdk(sdk-path: path) 
  Commit(hash: string)
  Version(version: string)

pub fun compiler/(==)(c1: compiler, c2: compiler): bool
  match (c1, c2)
    (Default, Default) -> True
    (Sdk(sdk-path1), Sdk(sdk-path2)) -> sdk-path1.string == sdk-path2.string
    (Commit(hash1), Commit(hash2)) -> hash1 == hash2
    (Version(version1), Version(version2)) -> version1 == version2
    (_, _) -> False

// Automatically generated.
// Shows a string representation of the `compiler` type.
pub fun compiler/show(this : compiler) : e string
  match this
    Default ->
      "Default"
    Sdk(sdk-path) ->
      "Path(sdk-path: " ++ show(sdk-path) ++ ")"
    Commit(hash) ->
      "Commit(hash: " ++ hash ++ ")"
    Version(version) ->
      "Version(version: " ++ version ++ ")"

pub type resolution
  Global(pkg-path: path)
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

pub value struct script 
  command: string
  execute: string;

pub fun script/(==)(s1: script, s2: script): bool
  match (s1, s2)
    (Script(command1, execute1), Script(command2, execute2)) ->
      command1 == command2 && execute1 == execute2

// Automatically generated.
// Shows a string representation of the `script` type.
pub fun script/show(this : script) : e string
  match this
    Script(command, execute) ->
      "Script(command: " ++ command ++ ", execute: " ++ execute ++ ")"
