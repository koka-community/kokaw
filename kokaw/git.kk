/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokaw/git
import kokaw/exec
import std/os/path
import std/os/process
import std/os/dir

// A git reference can be a commit hash, a branch name, or the default branch
pub value type git-ref
  GitCommit(hash: string)
  GitBranch(name: string)
  GitDefault

pub fun git-ref/(==)(r1: git-ref, r2: git-ref): bool
  match (r1, r2)
    (GitCommit(hash1), GitCommit(hash2)) -> hash1 == hash2
    (GitBranch(name1), GitBranch(name2)) -> name1 == name2
    (GitDefault, GitDefault) -> True
    (_, _) -> False

// Automatically generated.
// Shows a string representation of the `git-ref` type.
pub fun git-ref/show(this : git-ref) : e string
  match this
    GitCommit(hash) ->
      "GitCommit(hash: " ++ show(hash) ++ ")"
    GitBranch(name) ->
      "GitBranch(name: " ++ show(name) ++ ")"
    GitDefault ->
      "GitDefault"

// Get the git cli name of the ref (`main` is treated as default)
pub fun ref(r: git-ref)
  match r
    GitCommit(h) -> h
    GitBranch(b) -> b
    GitDefault -> "main"

// Checkout a git reference
pub fun checkout(commit: git-ref, repo-name: string)
  run("git sparse-checkout set examples " ++ repo-name) // Only include std/std & std/examples (not std/test, etc.)
  match commit
    GitDefault -> 
      val ref = run-system-read("git symbolic-ref refs/remotes/origin/HEAD --short").untry
      run("git checkout " ++ ref.split("/")[1].unjust)
      ()
    _ -> 
      run("git checkout " ++ commit.ref)
      ()

// Pull the latest changes
pub fun pull()
  run("git pull")
  ()

// Downloads or updates a git repository
pub fun download-or-update(name: string, url: string, repo-path: string, commit: git-ref, target-dir: path)
  if repo-path != "" then 
    throw("Unsupported repo-path")
  trace("Downloading " ++ name ++ " from " ++ url ++ " to " ++ target-dir.string)
  with fun current-dir() target-dir
  if is-directory(target-dir / name) then 
    with fun current-dir() target-dir / name
    checkout(commit, name)
    pull()
  else download(name, url, repo-path, commit)

// TODO: Add an option to fork / shallow fetch all the repo when cloning to set up for contributions from outside and inside the organization
pub fun download(name: string, url: string, repo-path: string, commit: git-ref)
  if repo-path != "" then 
    throw("Unsupported repo-path")
  match commit
    GitDefault ->
      run("git clone --filter=tree:0 \"" ++ url ++ "\" " ++ name)
      with fun current-dir() current-dir() / name
      commit.checkout(name)
    GitCommit -> 
      run("git clone --filter=tree:0 \"" ++ url ++ "\"" ++ name)
      with fun current-dir() current-dir() / name
      commit.checkout(name)
    GitBranch(b) ->
      run("git clone --filter=tree:0 -b " ++ b ++ " " ++ url ++ " " ++ name)
      with fun current-dir() current-dir() / name
      commit.checkout(name)