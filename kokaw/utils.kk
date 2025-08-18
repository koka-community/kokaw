import std/os/path
import std/os/dir
import std/os/env
import std/os/process
import kokaw/exec 
import kokaw/config 
import kokaw/package

extern import
  c file "utils.c"

extern string/file_modified(path: string): fsys maybe<int>
  c "kk_file_modified"

// Gets the last modification time of a file
pub fun path/file_modified(p: path): <fsys,exn> int
  p.string.file_modified.unjust

// Finds the package root, looking upwards from `folder`
pub fun find-package-root(folder: path): io path
  if folder.dirname == folder.string || folder.string == "" then
    throw("Couldn't find the package path")
  else
    if is-file(folder / "package.kk") then
      folder
    else
      find-package-root(folder.dirname.path)

// Adds `.exe` to the path if on windows 
pub fun exe-path(path: path): ndet path
  if get-os-name() == "windows" then path.change-ext(".exe") else path

// Makes a file executable
pub fun make-executable(p: path)
  if get-os-name() == "windows" then
    run("cmd /c attrib +x \"" ++ p.string ++ "\"")
  else
    run("/bin/bash -c \"chmod +x " ++ p.string ++ "\"")

pub fun path/(==)(p1: path, p2: path): bool
  p1.string == p2.string

// Determines a relative path from a `p: path`, and the expected `base: path` that `p` starts with 
pub fun relative-path(p: path, base: path): io path 
  // println("relative-path " ++ p.string ++ " " ++ base.string)
  val pparts = p.realpath.dirparts
  val bparts = base.realpath.dirparts
  fun go(b': list<string>, p': list<string>)
    match (b', p')
      (Nil, _) -> p'
      (_, Nil) -> throw("Cannot find relative path " ++ p.string.show ++ " " ++ base.string.show)
      (Cons(bh, bt), Cons(ph, pt)) ->
        if bh == ph then
          go(bt, pt)
        else
          throw("Cannot find relative path " ++ p.string.show ++ " " ++ base.string.show)
  // println("relative-path2 " ++ p.string ++ " " ++ base.string)
  go(bparts, pparts).foldl("".path, fn(acc, x) acc / x)

// Gets the command for a configured compiler
// Only supports `Default` and `Sdk` configurations
pub fun get-compiler-command(): <package-config,io> string
  match get-compiler()
    Default -> "koka"
    Sdk(sdk-path) -> 
      // TODO: Cache this?
      var command := "stack path --local-install-root"
      if get-os-name() != "windows" then
        val ghcenv = homedir() / "ghcup/env"
        if is-file(ghcenv) then 
          val shell = get-env-value("SHELL").default("bash")
          command := shell ++ " -c \"source " ++ ghcenv.string ++ " && stack path --local-install-root\""
      match run-system-read("cd \"" ++ sdk-path.string ++ "\" && " ++ command)
        Ok(build-path) -> 
          val koka-path = build-path.trim() / "bin" / "koka"
          if is-file(koka-path) then
            koka-path.string
          else
            throw("Compiler not found at " ++ koka-path.string)
    _ -> throw("Compiler configuration not supported yet")