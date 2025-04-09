/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/kokac
import std/os/path
import std/os/dir
import std/os/file
import std/os/process
import std/os/env
import kokac/package
import kokac/exec
import kokac/git
import kokac/config
import kokac/exec
import kokac/utils

// TODO: Check for changes / open editor in dependency
// TODO: VSCode extension (try to use official extension but with different Koka executable location, since this should mimic it)
// TODO: Default shallow clone. 
// TODO: Remove koka-community repo, and suggest migration to this tool

fun package-root() package-paths().package-root
fun last-deps-path() package-paths().last-deps-path
fun kokac-path() package-paths().kokac-path
fun package-path() package-paths().package-path
fun kokac-package-path() package-paths().kokac-package-path
fun package-runner-source() package-paths().package-runner-source
fun package-runner-exe() package-paths().package-runner-exe
fun update-runner-source() package-paths().update-runner-source
fun update-runner-exe() package-paths().update-runner-exe

fun mk-paths(root: path): <ndet> paths
  val kkc = root / ".kokac"
  // trace("kokac " ++ kkc.show)
  val p = Paths(
    package-root = root,
    package-path = root / "package.kk",
    kokac-path = kkc,
    kokac-package-path = kkc / "current" / "package.kk",
    last-deps-path = kkc / "last-deps",
    package-runner-source = kkc / "koka-package-runner.kk",
    package-runner-exe = (kkc / "koka-package-runner").exe-path,
    update-runner-source = kkc / "koka-update-runner.kk",
    update-runner-exe = (root / "koka").exe-path
  )
  // trace("next " ++ kkc.show)
  p

pub fun set-package-root(root: path, f: () -> <package-paths,ndet|e> a): <ndet|e> a
  // trace("package-root: " ++ root.string)
  with fun package-paths() mk-paths(root)
  f()

// Runs a file
fun run-file(file: path, args: list<string>): <package-paths,current-dir,package-config,io> int
  val args' = imports-args() ++ args
  val command = get-compiler-command() ++ " " ++ file.realpath.string ++ " " ++ args'.join(" ")
  println(command)
  run-result(command)

// Runs the language server or passes through arguments that don't contain a file
fun run-basic(args: list<string>): <package-paths,current-dir,package-config,io> int
  val args' = imports-args() ++ args
  val command = get-compiler-command() ++ " " ++ args'.join(" ")
  println(command)
  run-result(command)

fun download(dep: dependency, target-dir: path): io ()
  match dep.source
    GitDep(url, path, ref) -> download-or-update(dep.name, url, path, ref, target-dir)

fun deps-path(resolution: resolution): <package-paths,io> path
  match resolution
    Global(pkg-path) -> pkg-path
    Local -> package-root() / "deps"

fun install(): <package-config,package-paths,io> ()
  val download-dir = get-resolution().deps-path
  ensure-dir(download-dir)
  get-dependencies().foreach fn(dep)
    download(dep, download-dir)
  get-dev-dependencies().foreach fn(dep)
    download(dep, download-dir)
  ()

fun imports(): <package-config,package-paths,io> list<path>
  val top-path = get-resolution().deps-path
  (get-dependencies() ++ get-dev-dependencies()).map fn(dep)
    top-path / dep.name

fun imports-args(): <package-config,package-paths,io> list<string>
  imports().map(fn(p) "-i" ++ p.string)

val basic-test = r#"
import std/data/json
fun main()
  JSList([JSString("Hi")]).println
"#

val basic-package = r#"
import kokac/config

fun package()
  dependencies
    dep("std")
      "git@github.com:koka-community/std"
"#

pub fun name/init(nm: path): io ()
  val cd = if nm.is-absolute then nm else cwd() / nm
  println("Init " ++ cd.realpath.string)
  with fun current-dir() cd 
  val pkg = (current-dir() / "package.kk").realpath
  if !is-file(pkg) then
    write-text-file(pkg, basic-package, True)
  write-text-file(current-dir() / "bin" / "run.kk", basic-test, True)
  common/init()

pub fun basic/init(): io ()
  val pkg = cwd() / "package.kk"
  with fun current-dir() cwd()
  if !is-file(pkg) then
    write-text-file(pkg, basic-package)
  common/init()

noinline fun common/init(): <io,current-dir> ()
  with set-package-root(current-dir())
  init-directory()
  init-updater()
  init-package-runner()

fun init-directory(): <io,package-paths> ()
  val deps = package-root() / "deps"
  ensure-dir(deps)
  download-or-update("kokac", "https://github.com/koka-community/kokac", "", GitDefault, deps)
  ensure-dir(kokac-path())
  copy-package-file()

fun copy-package-file()
  ensure-dir(kokac-path() / "current")
  copy-file(package-path(), kokac-package-path())

fun init-updater()
  val runner = update-runner-source()
  val out = update-runner-exe()
  write-text-file(runner, update-runner(current-dir().string))
  write-text-file(last-deps-path(), "")
  run("koka " ++ runner.string ++ " -o\"" ++ out.string ++ "\" -i" ++ ("deps" / "kokac").string)
  make-executable(out)
  
fun init-package-runner()
  update-package-runner()
  build-package-runner()
  ()

fun update-runner(package-dir: string)
  r#"
import kokac/kokac
import std/os/path

fun main()
  bootstrap-package("# ++ package-dir.show ++ r#".path)
  ()
"#

pub fun bootstrap-package(package-dir: path)
  with fun current-dir() package-dir
  with set-package-root(package-dir)
  var needs-build := False
  while {out-of-date()} 
    println("Package config out of date")
    update-package-runner()
    needs-build := True
    ()
  if needs-build then
    build-package-runner()
    ()
  run-package-runner()

fun update-package-runner()
  val last-deps = current-packages(current-dir() / "deps");
  copy-file(package-path(), kokac-package-path())
  write-text-file(last-deps-path(), last-deps.join("\n"))  
  write-text-file(package-runner-source(), package-runner(last-deps))

fun out-of-date()
  val pkg = file_modified(package-path())
  val current = file_modified(package-runner-source())
  val deps = current-packages(current-dir() / "deps")
  val last-deps = parse-last-deps()
  if pkg > current then
    println("Package file out of date " ++ pkg.show ++ " " ++ current.show)
    True
  elif deps != last-deps then
    println("Current packages " ++ deps.show ++ " newer than last packages " ++ last-deps.show)
    True
  else False

fun parse-last-deps()
  val file = read-text-file(last-deps-path())
  file.split("\n").filter(fn(p) p != "")

fun build-package-runner()
  val out = package-runner-exe()
  run("koka " ++ package-runner-source().string ++ " -o \"" ++ out.string ++ "\" -ideps -i.kokac -i" ++ ("deps" / "kokac").string)
  make-executable(out)

fun run-package-runner()
  val args = get-args()
  run-result(package-runner-exe().string ++ " " ++ args.join(" "))

fun package-runner(deps: list<string>)
  r#"
import current/package
import kokac/config
import kokac/exec
import kokac/kokac
import kokac/utils
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
  install-run(package-path, ["# ++ 
    deps.map(fn(d) d ++ "/package/package").join(", ") ++
      r#"], last-deps)
  ()
"#

fun current-packages(dep-dir: path): io list<string>
  val packages = dep-dir.list-directory.filter fn(d)
    (d / "package.kk").is-file
  packages.map(fn(x) relative-path(x, dep-dir).string)

alias package-registrar = () -> <package-config> ()

pub fun install-run(package-path: path,
                    deps: list<package-registrar>, 
                    last-deps: list<string>): <current-dir,package-paths,package-config,io> int
  deps.foreach(submodule/config)
  install()
  if current-packages(get-resolution().deps-path) != last-deps then
    -1
  else
    val args = get-args()
    // Split the file from the rest of the arguments so we can resolve the package from the file
    val (file, rest) = args.span(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
    match file
      Cons(f, Nil) -> 
        run-file((cwd() / f).realpath, rest)
      _ -> 
        run-basic(args) // Just passthrough the arguments using the cwd as location to resolve package file from.

