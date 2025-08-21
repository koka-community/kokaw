/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokaw/kokaw
import std/os/path
import std/os/dir
import std/os/file
import std/os/flags
import std/os/process
import std/os/env
import kokaw/package
import kokaw/exec
import kokaw/git
import kokaw/config
import kokaw/exec
import kokaw/utils

// TODO: Check for changes / open editor in dependency
// TODO: VSCode extension (try to use official extension but with different Koka executable location, since this should mimic it)
// TODO: Default shallow clone. 
// TODO: Remove koka-community repo, and suggest migration to this tool

// Some utility functions for accessing common paths
fun package-root() package-paths().package-root
fun last-deps-path() package-paths().last-deps-path
fun kokaw-path() package-paths().kokaw-path
fun package-path() package-paths().package-path
fun kokaw-package-path() package-paths().kokaw-package-path
fun package-runner-source() package-paths().package-runner-source
fun package-runner-exe() package-paths().package-runner-exe
fun update-runner-source() package-paths().update-runner-source
fun update-runner-exe() package-paths().update-runner-exe

// Determines the paths for `.kokaw` configuration and script files.
fun mk-paths(root: path): <ndet> paths
  val kkc = root / ".kokaw"
  // trace("kokaw " ++ kkc.show)
  val p = Paths(
    package-root = root,
    package-path = root / "package.kk",
    kokaw-path = kkc,
    kokaw-package-path = kkc / "current" / "package.kk",
    last-deps-path = kkc / "last-deps",
    package-runner-source = kkc / "koka-package-runner.kk",
    package-runner-exe = (kkc / "koka-package-runner").exe-path,
    update-runner-source = kkc / "koka-update-runner.kk",
    update-runner-exe = (root / "kokaw").exe-path
  )
  // trace("next " ++ kkc.show)
  p

// Sets the package root directory
pub fun set-package-root(root: path, f: () -> <package-paths,ndet|e> a): <ndet|e> a
  // trace("package-root: " ++ root.string)
  with fun package-paths() mk-paths(root)
  f()

// Compiles a `file` with `args` using the package config to determine include paths.
fun run-file(file: path, args: list<string>): <package-paths,current-dir,package-config,io> int
  val args' = includes-args() ++ args
  val command = get-compiler-command() ++ " " ++ file.realpath.string ++ " " ++ args'.join(" ")
  println(command)
  run-result(command)

// Runs the language server or passes through arguments that don't contain a file.
// Uses the package config to determine the include paths.
fun run-basic(args: list<string>): <package-paths,current-dir,package-config,io> int
  val args' = includes-args() ++ args
  val command = get-compiler-command() ++ " " ++ args'.join(" ")
  println(command)
  run-result(command)

// Downloads a git `dep` to the `target-dir`
fun download(dep: dependency, target-dir: path): io ()
  match dep.source
    GitDep(url, path, ref) -> download-or-update(dep.name, url, path, ref, target-dir)

// Determines the cache path for dependencies
fun deps-path(resolution: resolution): <package-paths,io> path
  match resolution
    Global(pkg-path) -> pkg-path
    Local -> package-root() / "deps"

// Install dependencies
fun install(): <package-config,package-paths,io> ()
  val download-dir = get-resolution().deps-path
  ensure-dir(download-dir)
  get-dependencies().foreach fn(dep)
    download(dep, download-dir)
  get-dev-dependencies().foreach fn(dep)
    download(dep, download-dir)
  ()

// Get the include paths for dependencies
fun includes(): <package-config,package-paths,io> list<path>
  val top-path = get-resolution().deps-path
  val regular-deps = (get-dependencies() ++ get-dev-dependencies()).map fn(dep)
    top-path / dep.name
  Cons(top-path / "kokaw", regular-deps)

// Get include arguments for the koka compiler
fun includes-args(): <package-config,package-paths,io> list<string>
  includes().map(fn(p) "-i" ++ p.string)

// Basic package `bin/run.kk` file for testing dependencies install
val basic-test = r#"
import std/data/json
fun main()
  JSList([JSString("Hi")]).println
"#

// Basic `package.yaml` template file
val basic-package = r#"
import kokaw/config

fun package()
  dependencies
    dep("std")
      "git@github.com:koka-community/std"
"#

// Initializes a new package in `path`
pub fun name/init(path: path): io ()
  val cd = if path.is-absolute then path else cwd() / path
  println("Init " ++ cd.realpath.string)
  with fun current-dir() cd 
  val pkg = (current-dir() / "package.kk").realpath
  if !is-file(pkg) then
    write-text-file(pkg, basic-package, True)
  write-text-file(current-dir() / "bin" / "run.kk", basic-test, True)
  common/init()

// Initializes a new package in the current directory
// Only adds `package.yaml` and no other template files or directories
pub fun basic/init(): io ()
  val pkg = cwd() / "package.kk"
  with fun current-dir() cwd()
  if !is-file(pkg) then
    write-text-file(pkg, basic-package)
  common/init()

// Initializes the package directory, the updater script, and the `./kokaw` runner.
noinline fun common/init(): <io,current-dir> ()
  with set-package-root(current-dir())
  init-directory()
  init-updater()
  init-package-runner()

// Initializes basic dependencies (`kokaw`), and sets up the `.kokaw` directory.
fun init-directory(): <io,package-paths> ()
  val deps = package-root() / "deps"
  ensure-dir(deps)
  download-or-update("kokaw", "https://github.com/koka-community/kokaw", "", GitDefault, deps)
  ensure-dir(kokaw-path())
  copy-package-file()

// Copies the package file to the kokaw directory
fun copy-package-file()
  ensure-dir(kokaw-path() / "current")
  copy-file(package-path(), kokaw-package-path())

// Initializes the updater (keeping the `./kokaw` script up to date with changes to the `package.yaml` file)
fun init-updater()
  val runner = update-runner-source()
  val out = update-runner-exe()
  write-text-file(runner, update-runner(current-dir().string))
  write-text-file(last-deps-path(), "")
  println("Building the `kokaw` wrapper executable")
  run("koka " ++ runner.string ++ " -o\"" ++ out.string ++ "\" -i" ++ ("deps" / "kokaw").string)
  make-executable(out)
  
// Initializes the `./kokaw` script the first time, updating and building the `.kokaw/koka-package-runner`
fun init-package-runner()
  update-package-runner()
  build-package-runner()
  ()

// The template for the script to update the `./kokaw` runner
fun update-runner(package-dir: string)
  r#"
import kokaw/kokaw
import kokaw/utils
import std/os/path

fun main()
  process-exit(bootstrap-package("# ++ package-dir.show ++ r#".path))
"#

// Bootstraps the package by ensuring all dependencies are installed
pub fun bootstrap-package(package-dir: path)
  with fun current-dir() package-dir
  with set-package-root(package-dir)
  var needs-build := False
  while {out-of-date()} 
    update-package-runner()
    needs-build := True
    ()
  if needs-build then
    build-package-runner()
    var result := run-result(package-runner-exe().string ++ " check-deps")
    while {result == exit-code-changed-deps}
      update-package-runner()
      build-package-runner()
      result := run-result(package-runner-exe().string ++ " check-deps")
    println("Result " ++ result.show)
  run-package-runner()

// Updates the `.kokaw/koka-package-runner` script
fun update-package-runner()
  val last-deps = current-packages(current-dir() / "deps");
  copy-file(package-path(), kokaw-package-path())
  write-text-file(last-deps-path(), last-deps.join("\n"))  
  write-text-file(package-runner-source(), package-runner(last-deps))

// Checks to see if the `package.yaml` file has changed
fun out-of-date()
  val pkg = file_modified(package-path())
  val current = file_modified(package-runner-source())
  val deps = current-packages(current-dir() / "deps")
  val last-deps = parse-last-deps()
  if pkg > current then
    trace("Package file out of date " ++ pkg.show ++ " " ++ current.show)
    True
  elif deps != last-deps then
    trace("Current packages " ++ deps.show ++ " newer than last packages " ++ last-deps.show)
    True
  else False

// Check to see if the deps have changed.
fun parse-last-deps()
  val file = read-text-file(last-deps-path())
  file.split("\n").filter(fn(p) p != "")

// Build the `.kokaw/koka-package-runner` wrapper
fun build-package-runner()
  trace("Building `package.kk` with new dependencies")
  val out = package-runner-exe()
  run("koka " ++ package-runner-source().string ++ " -o \"" ++ out.string ++ "\" -ideps -i.kokaw -i" ++ ("deps" / "kokaw").string)
  make-executable(out)

// Run the `.kokaw/koka-package-runner` wrapper
fun run-package-runner()
  val args = get-args()
  run-result(package-runner-exe().string ++ " " ++ args.join(" "))

// The template for the `.kokaw/koka-package-runner` wrapper
fun package-runner(deps: list<string>)
  r#"
import current/package
import kokaw/config
import kokaw/exec
import kokaw/kokaw
import kokaw/utils
import std/os/env
import std/os/path
import std/os/dir
"# ++ deps.map(fn(d) "\nimport " ++ d ++ "/package").join("") ++ r#"

val package-path = "# ++ package-path().show ++ r#".path
val last-deps = ["# ++ deps.map(fn(d) "\"" ++ d ++ "\"").join(", ") ++ r#"]

fun main()
  with fun current-dir() cwd()
  with set-package-root(find-package-root(current-dir()))
  with default-package-config(current/package/package)
  process-exit(install-run(package-path, ["# ++ 
    deps.map(fn(d) d ++ "/package/package").join(", ") ++
      r#"], last-deps))
"#

// Get the current dependencies in the `deps` directory that have `package.yaml` dependency files.
fun current-packages(dep-dir: path): io list<string>
  val packages = dep-dir.list-directory.filter fn(d)
    (d / "package.kk").is-file
  packages.map(fn(x) relative-path(x, dep-dir).string)

alias package-registrar = () -> <package-config> ()

val exit-code-changed-deps = 100

// Install dependencies then attempt to run with the arguments.
pub fun install-run(package-path: path,
                    deps: list<package-registrar>, 
                    last-deps: list<string>): <current-dir,package-paths,package-config,io> int
  deps.foreach(dep/config)
  install()
  if current-packages(get-resolution().deps-path) != last-deps then
    
    val args = get-args()
    match args
      Cons("check-deps") ->
        println("Dependencies changed... should update package script...") 
        exit-code-changed-deps
      _ -> 
        println("Dependencies have changed, please run again")
        -1
  else
    val args = get-args()
    match args
      Nil -> 
        println("No arguments to koka, running `koka --help`")
        run-basic(["--help"])
      Cons(arg, rest) ->
        if arg == "run" then 
          // Lookup script
          val scripts = get-scripts()
          match rest
            Nil -> 
              println("No script specified, options:\n" ++ scripts.map(show).join("\n"))
              // -1
            Cons(name, script-args) -> 
              match scripts.filter(_.command == name).head
                Nothing -> 
                  println("Script not found, assuming `koka -e " ++ args.join(" ") ++ "`")
                  // -1
                Just(script) -> 
                  match script
                    SimpleScript(_, execute) -> run-result(execute ++ " " ++ script-args.join(" "))
                    KokaScript(_, flags, default, execute) ->
                      val (flags', args', errs) = parse(default, flags, script-args)
                      if errs.is-nil then
                        execute(flags', args')
                      else 
                        println(script.show)
                        -1
                      // Run the script with the flags and arguments       
                  ()
                  // -1
        // Split the file from the rest of the arguments so we can resolve the package from the file
        val (files, koka-args) = args.span(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
        match files
          Cons(f, Nil) -> 
            run-file((cwd() / f).realpath, koka-args)
          _ -> 
            run-basic(args) // Just passthrough the arguments using the cwd as location to resolve package file from.

