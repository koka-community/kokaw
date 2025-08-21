:: Build the kokaw tool
koka.exe -o"bin/kokaw.exe" "bin/kokaw.kk"
:: Make it executable
attrib +x bin\kokaw.exe

:: Remove old versions of the test project
if exist test2 (
  rd /S /Q test2 
)
:: Init a test project
.\bin\kokaw.exe init test2
:: Change to the test project directory
pushd test2
:: Make sure the test project can run
kokaw.exe -e "bin/run.kk"