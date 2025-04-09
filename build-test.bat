:: Build the kokac tool
koka.exe -o"bin/kokac.exe" "bin/kokac.kk"
:: Make it executable
attrib +x bin\kokac.exe

:: Remove old versions of the test project
if exist test2 (
  rd /S /Q test2 
)
:: Init a test project
.\bin\kokac.exe init test2
:: Change to the test project directory
pushd test2
:: Make sure the test project can run
koka.exe -e "bin/run.kk"