import kokac/config

fun package()
  dependencies
    dep("parsing", branch="kokac")
      "git@github.com:koka-community/parsing"
    // dep("std")
    //   "git@github.com:koka-community/std"
  scripts
    script("run")
      "echo \"Hello World\""