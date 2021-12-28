Command to start build:

$ build.ps1 -buildversion <version> [-forlinux] <true|false> [-dotnetruntimelinux] <dotnet-run-file-path> [-pushcontainerimage] <true|false>


eg:

$ build.ps1 -buildversion "3.3.40"
$ build.ps1 -buildversion "3.3.40" -pushcontainerimage "true"
