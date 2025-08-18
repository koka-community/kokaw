/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokaw/config
import kokaw/package
import kokaw/exec
import kokaw/git
import std/os/process
pub import std/os/path
pub import std/os/flags
import std/os/env
import std/core/unsafe

// Contains the paths relevant for `kokaw` package management.
pub struct paths
  package-root: path // The root of the current package
  package-path: path // The path to the `package.yaml` file
  kokaw-path: path // The path to the `.kokaw` folder where `.kokaw` related files live
  last-deps-path: path // The file that keeps track of the last known dependencies
  kokaw-package-path: path // The path to the `package.yaml` file copied to `.kokaw` to check for package configuration changes
  package-runner-source: path // The path to the koka wrapper script
  package-runner-exe: path // The path to the koka wrapper executable
  update-runner-source: path // The path to the update script
  update-runner-exe: path // The path to the update executable

// Returns the package paths
pub effect package-paths
  fun package-paths(): paths

// Contains the package configuration operations.
pub effect package-config
  fun set-dependencies(deps: list<dependency>): ()
  fun set-dev-dependencies(deps: list<dependency>): ()
  fun set-scripts(scripts: list<script>): ()
  fun set-compiler(compiler: compiler): ()
  fun set-resolution(resolution: resolution): ()
  fun get-dependencies(): list<dependency>
  fun get-dev-dependencies(): list<dependency>
  fun get-scripts(): list<script>
  fun get-compiler(): compiler
  fun get-resolution(): resolution

// Provides the handler for package configuration for the target package.
pub fun default-package-config(f: () -> <package-config> (), install: () -> <io,current-dir,package-paths,package-config> ()): <io,current-dir,package-paths> ()
  var deps := []
  var scripts := []
  var dev-deps := []
  var compiler := Default
  var resolution := Local
  with handler
    fun set-dependencies(deps_new) deps := deps_new.unique
    fun set-dev-dependencies(dev-deps_new) dev-deps := dev-deps_new.unique
    fun set-scripts(scripts_new) scripts := scripts_new
    fun set-compiler(compiler_new) compiler := compiler_new
    fun set-resolution(resolution_new) resolution := resolution_new
    fun get-dependencies() deps
    fun get-dev-dependencies() dev-deps
    fun get-scripts() scripts
    fun get-compiler() compiler
    fun get-resolution() resolution
  f()
  install()

// Provides the package configuration handler for the dependent packages
//   but do not affect the dev-dependencies, compiler, resolution, or scripts defined in the main package
pub fun dep/config(f: () -> package-config ()): package-config ()
  with override
    fun set-dependencies(deps_new) set-dependencies(deps_new)
    fun set-dev-dependencies(dev-deps_new) ()
    fun set-scripts(scripts_new) ()
    fun set-compiler(compiler_new) ()
    fun set-resolution(resolution_new) ()
    fun get-dependencies() get-dependencies()
    fun get-dev-dependencies() get-dev-dependencies()
    fun get-scripts() get-scripts()
    fun get-compiler() get-compiler()
    fun get-resolution() get-resolution()
  f()

// A handler to manage dependencies
effect dependencies
  fun add-dep(d: dependency): ()

// The dependencies section
// ```koka
// dependencies
//   dep(name, branch="optional-branch-name")
//     "<git-repo-url>"
//   ...
// ```
pub fun dependencies(f : () -> <dependencies,package-config> ()) : package-config ()
  var deps := []
  with fun add-dep(d) deps := Cons(d, deps)
  mask<local>{f()}
  set-dependencies((deps ++ get-dependencies()))

// The dev-dependencies section
// ```koka
// dev-dependencies
//   dep(name, branch="optional-branch-name")
//     "<git-repo-url>"
//   ...
// ```
pub fun dev-dependencies(f : () -> <dependencies,package-config> ()) : package-config ()
  var deps := []
  with fun add-dep(d) deps := Cons(d, deps)
  mask<local>{f()}
  set-dev-dependencies((deps ++ get-dev-dependencies()))

// Adds a git dependency
// ```koka
// dependencies
//   dep(name, branch="optional-branch-name")
//     "<git-repo-url>"
// ```
pub fun dep(name: string, git: () -> string, branch: string = ""): dependencies ()
  add-dep(Dependency(name, GitDep(git(), "", if branch.is-empty then GitDefault else GitBranch(branch))))

// An effect that allows you to use `script()` sugar functions to define scripts for your package
// See `simple/script`, `koka-simple/script`, and `koka/script`.
pub effect scripts
  fun add-script(script: script): ()

// ```koka
// scripts
//   script(name)
//      "<os-command>"
// ```
// execute via `./kokaw run <name> args ...`
pub fun simple/script(name: string, command: () -> string): scripts ()
  add-script(SimpleScript(name, command()))

// ```koka
// scripts
//   script(name) fn(args)
//      ... // your Koka script logic
// ```
// execute via `./kokaw run <name> args ...`
pub fun koka-simple/script(name: string, execute: (list<string>) -> io-noexn int): scripts ()
  add-script(KokaScript(name, [], (), fn(_, args) execute(args)))

// ```koka
// scripts
//   script(name, flags-default, flags=[...]) fn(parsed-flags, args)
//      ... // your Koka script with `std/os/flags` parsed flags
// ```
// execute via `./kokaw run <name> -f --flag=<value> args ...`
pub fun koka/script(name: string, default: a, execute: (a, list<string>) -> io-noexn int, flags: list<flag<a>> = []): scripts ()
  add-script(KokaScript(name, flags, default, execute))

// Wraps `script()` functions adding them to this package config
pub fun scripts(f: () -> <package-config,scripts> ()): package-config ()
  var scripts := []
  with fun add-script(script) scripts := Cons(script, scripts)
  mask<local>{f()}
  set-scripts(scripts)

// `path` defaults to XDG_DATA_DIR/.kokaw
// currently packages are stored versionless, but hopefully that will change eventually...)
pub fun global-package-cache(path: path = unsafe-total(default-global-path) / ".kokaw"): package-config ()
  set-resolution(Global(path))

// local stores it relative to the package.yaml (in deps/) - make sure to .gitignore
pub fun local-package-cache()
  set-resolution(Local)

// Determines the default global path for the package cache
pub fun default-global-path(): io-noexn path
  val res = try
    if get-os-name() == "windows" then 
      match run-system-read("%LOCALAPPDATA%")
        Ok(res) -> res.trim.path
    else 
      match run-system-read("echo $XDG_DATA_HOME")
        Ok(res) -> match res.trim
            "" -> run-system-read("echo $HOME").untry.trim.path
            p -> p.path
        Error -> run-system-read("echo $HOME").untry.trim.path
  match res
    Ok(res) -> res
    Error(_) -> "".path

// Sets the compiler, not currently handled.
pub fun compiler(comp: compiler): package-config ()
  set-compiler(comp)