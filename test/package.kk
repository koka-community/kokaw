import kokaw/config

fun package()
  dependencies
    dep("parsing", branch="kokaw")
      "git@github.com:koka-community/parsing"
    // dep("std")
    //   "git@github.com:koka-community/std"
  scripts
    script("run")
      "echo \"Hello World\""