import kokac/package
import kokac/kokac
import std/os/path

fun main()
  println("../kokac/test")
  init("../kokac/test".realpath)
  // run("../kokac/test/bin/run.kk".path, ["-e"])
  ()
  
