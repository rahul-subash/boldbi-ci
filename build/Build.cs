using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Runtime.InteropServices;
using System.Xml;
using System.Xml.Linq;
using Microsoft.Build.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using NuGet.Versioning;
using Nuke.Common;
using Nuke.Common.Execution;
using Nuke.Common.IO;
using Nuke.Common.Tooling;
using Nuke.Common.Tools.Docker;
using Nuke.Common.Tools.DotNet;
using Nuke.Common.Tools.Git;
using Nuke.Common.Utilities.Collections;
using YamlDotNet.Serialization;

namespace BoldBICI
{
    [UnsetVisualStudioEnvironmentVariables]
    class Build : NukeBuild
    {
        public static int Main() => Execute<Build>(execute => execute.BuildPack);

        AbsolutePath OutputDir => RootDirectory / "build-output";
        AbsolutePath BoldBIOutputDir => OutputDir / "boldbi";
        AbsolutePath ServicesOutputDir => OutputDir / "services";
        AbsolutePath DotnetOutputDir => OutputDir / "dotnet";
        AbsolutePath WorkingDir => RootDirectory / "repos";
        AbsolutePath ClientlibraryOutputDir => OutputDir / "clientlibrary";
        AbsolutePath licensedir => OutputDir / "Infrastructure";
        AbsolutePath utilitiesdir => OutputDir / "utilities";

        string Powershell => ToolPathResolver.GetPathExecutable(RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "powershell" : "pwsh");
        string Outputfile => "BoldBIEnterpriseEdition_Linux_" + DateTime.UtcNow.ToString("yyyy'-'MM'-'dd'T'HH'-'mm'-'ss'-GMT'") + ".zip";

        [Parameter(Name = "forlinux")]
        string ForLinux = "true";

        [Parameter(Name = "dotnetruntimelinux")]
        string DotnetRuntimeLinux = "aspnetcore-runtime-3.1.9-linux-x64.tar.gz";

        [Parameter(Name = "buildversion")]
        string BuildVersion ;

        [Parameter(Name = "tagversion")]
        string Tagversion;

        [Parameter(Name = "pushcontainerimage")]
        string PushContainerImage = "false";

        public BuildInformation BuildInformation =>
            JsonConvert.DeserializeObject<BuildInformation>(File.OpenText(RootDirectory / "build/buildinformation.json").ReadToEnd());

        Target SourceSetup => _ => _
        .Executes(() =>
        {
            ////Delete output dirs
            FileSystemTasks.DeleteDirectory(BoldBIOutputDir);
            FileSystemTasks.DeleteDirectory(ServicesOutputDir);
            FileSystemTasks.DeleteDirectory(DotnetOutputDir);
            FileSystemTasks.DeleteDirectory(ClientlibraryOutputDir);
            FileSystemTasks.DeleteDirectory(licensedir);
            FileSystemTasks.DeleteDirectory(utilitiesdir);
            

            ////Create outpur dirs
            Directory.CreateDirectory(WorkingDir);
            Directory.CreateDirectory(OutputDir);
            Directory.CreateDirectory(BoldBIOutputDir);

            ////Output File
            Logger.Success("Zip package output name: " + Outputfile);

            foreach (var project in BuildInformation.Projects)
            {
                if (FileSystemTasks.DirectoryExists(WorkingDir / project.Name))
                {
                    GitTasks.Git("reset --hard", WorkingDir / project.Name);
                    GitTasks.Git("pull", WorkingDir / project.Name);
                }
                else
                {
                    GitTasks.Git("clone -b " + project.Branch + " " + project.Repo + " " + project.Name, WorkingDir);
                }
            }
        });

        Target UpdateVersion => _ => _
        .DependsOn(SourceSetup)
        .Requires(() => BuildVersion)
        .Executes(() =>
        {
            ////Update version
            foreach (var file in BuildInformation.Versioning.Files)
            {
                var versionedFile = WorkingDir / file;

                if (FileSystemTasks.FileExists(versionedFile))
                {
                    var xmlDoc = XDocument.Load(versionedFile);
                    xmlDoc.Descendants().Where(w => w.Value == "latest").FirstOrDefault().Value = BuildVersion;
                    xmlDoc.Save(versionedFile);

                    Logger.Info("Updated version in " + versionedFile);
                }
            }
        });

        Target PublishProjects => _ => _
        .DependsOn(UpdateVersion)
        .Executes(() =>
        {
            ////Start publishing of all modules
            foreach (var project in BuildInformation.Projects.OrderBy(o => o.BuildOrder))
            {
                var projectDir = WorkingDir / project.Name;
                var buildDir = projectDir / "build";

                ////BeforeBuild Actions
                if (project.BeforeBuild != null)
                {
                    Logger.Info("Before Build Actions " + project.Name);
                }

                ////Build Actions
                Logger.Info("Publishing Project " + project.Name);
                ProcessTasks.StartProcess(Powershell, project.BuildCmd + " -StudioVersion "+BuildVersion, buildDir).AssertWaitForExit();

                ////AfterBuild Actions
                if (project.AfterBuild != null)
                {
                    Logger.Info("After Build Actions " + project.Name);
                    foreach (var action in project.AfterBuild.FileCopyActions)
                    {
                        var source = WorkingDir / project.Name + "/" + action.SourceDir;
                        var destination = action.OutputDirType == DirType.Output ? BoldBIOutputDir / action.DestDir : WorkingDir / action.DestDir;

                        if (FileSystemTasks.FileExists((AbsolutePath)(source)))
                        {
                            FileSystemTasks.CopyFileToDirectory(
                                source,
                                destination,
                                FileExistsPolicy.Overwrite,
                                true);
                        }
                        else
                        {
                            FileSystemTasks.CopyDirectoryRecursively(
                                source,
                                destination,
                                DirectoryExistsPolicy.Merge,
                                FileExistsPolicy.Overwrite);
                        }
                    }
                }
            }
        });

        Target MovePublishedProjects => _ => _
        .DependsOn(PublishProjects)
        .Executes(() =>
        {
            ////Get App
            Logger.Info("Moving published apps to CI output");
            foreach (var project in BuildInformation.Projects)
            {
                var projectDir = WorkingDir / project.Name;

                foreach (var projectOutput in project.BuildOutputs)
                {
                    var projectOutputDir = projectOutput.OutputDirType == DirType.Output ?
                                            BoldBIOutputDir / projectOutput.DestDir : WorkingDir / projectOutput.DestDir;

                    FileSystemTasks.CopyDirectoryRecursively(
                        projectDir + "/" + projectOutput.SourceDir,
                        projectOutputDir,
                        DirectoryExistsPolicy.Merge,
                        FileExistsPolicy.Overwrite);
                }
            }

            Logger.Info("delete pdp files");

            Directory.GetFiles(OutputDir, "*.pdb", SearchOption.AllDirectories)
            .ToList()
            .ForEach(file =>
            FileSystemTasks.DeleteFile(file));

            Logger.Info("Add client library and license agreement");
            moveadminutilsandlicense();
            CreateClientLibrary();
        });

        public void moveadminutilsandlicense()
         {
             Logger.Info("move admin utils");
             var source = WorkingDir +"/idp/output/utilities";
             var destination = OutputDir + "/utilities/adminutils";

             //if (FileSystemTasks.FileExists((AbsolutePath)(source)))
             //{
             //    FileSystemTasks.CopyFileToDirectory(
             //        source,
             //        destination,
             //        FileExistsPolicy.Overwrite,
             //        true);
             //}
             //else
             //{
             //    FileSystemTasks.CopyDirectoryRecursively(
             //        source,
             //        destination,
             //        DirectoryExistsPolicy.Merge,
             //        FileExistsPolicy.Overwrite);
             //}

             Logger.Info("Move license agreement");
             source = RootDirectory + "/Infrastructure/License Agreement";
             destination = OutputDir + "/Infrastructure/License Agreement";
             if (FileSystemTasks.FileExists((AbsolutePath)(source)))
             {
                 FileSystemTasks.CopyFileToDirectory(
                     source,
                     destination,
                     FileExistsPolicy.Overwrite,
                     true);
             }
             else
             {
                 FileSystemTasks.CopyDirectoryRecursively(
                     source,
                     destination,
                     DirectoryExistsPolicy.Merge,
                     FileExistsPolicy.Overwrite);
             }

         }
   
        public void CreateClientLibrary()
        {
            foreach(var assembly in BuildInformation.optionalassemblies)
            {
                Directory.GetFiles(OutputDir + "/boldbi/bi/dataservice", assembly, SearchOption.AllDirectories)
          .ToList()
          .ForEach(file =>
          {
             
              FileSystemTasks.CopyFileToDirectory(
             file,
             ClientlibraryOutputDir,
             FileExistsPolicy.Overwrite,
             true);
              FileSystemTasks.DeleteFile(file);
          });

            }
            CompressionTasks.CompressZip(ClientlibraryOutputDir, ClientlibraryOutputDir +"/clientlibrary.zip", null, CompressionLevel.Optimal);

            foreach (var assembly in BuildInformation.optionalassemblies)
            {
                FileSystemTasks.DeleteFile(ClientlibraryOutputDir/assembly);
            }
            Logger.Info("Move library help me file");
            var source = RootDirectory + "/clientlibrary";
            var destination = ClientlibraryOutputDir;
            if (FileSystemTasks.FileExists((AbsolutePath)(source)))
            {
                FileSystemTasks.CopyFileToDirectory(
                    source,
                    destination,
                    FileExistsPolicy.Overwrite,
                    true);
            }
            else
            {
                FileSystemTasks.CopyDirectoryRecursively(
                    source,
                    destination,
                    DirectoryExistsPolicy.Merge,
                    FileExistsPolicy.Overwrite);
            }

        }

        Target BuildPack => _ => _
        .DependsOn(MovePublishedProjects)
        .Requires(() => ForLinux)
        .Requires(() => Tagversion)
        .Executes(() =>
        {
            ////Get Dotnet runtime
            Logger.Info("Download dotnet runtime");
            if (Convert.ToBoolean(ForLinux))
            {
                var dotnetRuntimeLinux = OutputDir / DotnetRuntimeLinux;

                Logger.Info("Started downloading dotnet runtime for linux");
                HttpTasks.HttpDownloadFile("https://dotnetcli.azureedge.net/dotnet/aspnetcore/Runtime/3.1.9/aspnetcore-runtime-3.1.9-linux-x64.tar.gz", dotnetRuntimeLinux);

                Logger.Info("Extracting dotnet runtime for linux");
                CompressionTasks.UncompressTarGZip(dotnetRuntimeLinux, DotnetOutputDir);
            }
            else
            {
                ProcessTasks.StartProcess(Powershell, "-NoProfile -ExecutionPolicy unrestricted -Command \"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; &([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://dot.net/v1/dotnet-install.ps1'))) -NoPath -Runtime aspnetcore -InstallDir dotnet \" ", OutputDir).AssertWaitForExit();
            }

            ////Get service files
            Logger.Info("Pack service files");

            Directory.GetFiles(WorkingDir, "*.service", SearchOption.AllDirectories)
            .ToList()
            .ForEach(file =>
            FileSystemTasks.CopyFileToDirectory(
                file,
                ServicesOutputDir,
                FileExistsPolicy.Overwrite,
                true));

            ////Delete runtime after extraction
            if (Convert.ToBoolean(ForLinux))
            {
                FileSystemTasks.DeleteFile(OutputDir / DotnetRuntimeLinux);
            }

            ////Compress package
            Logger.Info("Zip the app");
            FileSystemTasks.DeleteFile(OutputDir / Outputfile);
            CompressionTasks.CompressZip(OutputDir, OutputDir / Outputfile, null, CompressionLevel.Optimal);

            if (PushContainerImage.ToString().ToLower() == "false")
            {
                new Build().BuildAndPushContainerImage(Tagversion);
            }
        });

        Target PushToLinux => _ => _
        .DependsOn(BuildPack)
        .Executes(() =>
        {
            var uploadFileName = "boldbi_ftp_" + DateTime.UtcNow.ToString("yyyy'-'MM'-'dd'T'HH'-'mm'-'ss'-GMT'") + ".zip";
            var localFileToUpload = OutputDir / uploadFileName;

            FileSystemTasks.CopyFile(OutputDir / Outputfile, localFileToUpload, FileExistsPolicy.Overwrite);

            FtpTasks.FtpCredentials = new NetworkCredential(BuildInformation.LinuxMachineDetails.Username,
                BuildInformation.LinuxMachineDetails.Password);

            FtpTasks.FtpUploadFile(localFileToUpload, BuildInformation.LinuxMachineDetails.Domain + uploadFileName);
        });

        public void MoveFilesForImage()
        {
            //// Move products.json file
            FileSystemTasks.CopyFileToDirectory(
                BoldBIOutputDir / "app_data/configuration/product.json",
                RootDirectory / "movesharedfiles/MoveSharedFiles/app_data/configuration",
                FileExistsPolicy.Overwrite);

            ////Start building MoveSharedFiles utility
            Logger.Info("Running MoveSharedFiles utility");
            DotNetTasks.DotNetPublish(build =>
            build
            .SetOutput(RootDirectory / "movesharedfiles/MoveSharedFiles/publish/MoveSharedFiles")
            .SetConfiguration("Release")
            .SetProcessWorkingDirectory(RootDirectory / "movesharedfiles/MoveSharedFiles"));

            var idpWebPath = BoldBIOutputDir
                / BuildInformation.Projects.Where(x => x.Name == "idp").FirstOrDefault().BuildOutputs.Where(y => y.Name == "web").FirstOrDefault().DestDir;

            var designerPath = BoldBIOutputDir
                / BuildInformation.Projects.Where(x => x.Name == "designer").FirstOrDefault().BuildOutputs.Where(y => y.Name == "dataservice").FirstOrDefault().DestDir;

            if (!Directory.Exists(idpWebPath / "appdatafiles/MoveSharedFiles"))
            {
                Directory.CreateDirectory(idpWebPath / "appdatafiles/MoveSharedFiles");
            }

            ////Start moving necessary container image files
            Logger.Info("Moving necessary container image files");

            FileSystemTasks.CopyDirectoryRecursively(
                RootDirectory / "movesharedfiles/MoveSharedFiles/publish/MoveSharedFiles",
                idpWebPath / "appdatafiles/MoveSharedFiles",
                DirectoryExistsPolicy.Merge,
                FileExistsPolicy.Overwrite);

            CompressionTasks.UncompressZip(ClientlibraryOutputDir + "/clientlibrary.zip", idpWebPath / "appdatafiles/MoveSharedFiles/app_data/optional-libs");

            FileSystemTasks.CopyFileToDirectory(
                RootDirectory / "movesharedfiles/MoveSharedFiles/shell_scripts/id_web/entrypoint.sh",
                idpWebPath, 
                FileExistsPolicy.Overwrite);

            FileSystemTasks.CopyFileToDirectory(
                RootDirectory / "movesharedfiles/MoveSharedFiles/shell_scripts/designer/entrypoint.sh",
                designerPath, 
                FileExistsPolicy.Overwrite);

            FileSystemTasks.CopyFileToDirectory(
                RootDirectory / "movesharedfiles/MoveSharedFiles/shell_scripts/designer/install-optional.libs.sh",
                designerPath, 
                FileExistsPolicy.Overwrite);
        }

        public void BuildAndPushContainerImage(string tagVersion)
        {
            //Move necessary files for container image
            //MoveFilesForImage();

            var containerImages = new List<string>();
            Logger.Info("Creating container images");
            var buildOutputs = new List<BuildOutputs>();
            BuildInformation.Projects.ForEach(x => buildOutputs.AddRange(x.BuildOutputs.ToList()));

            var dockerfilePath = Path.GetFullPath(BoldBIOutputDir + "/Dockerfile");
            if (File.Exists(dockerfilePath))
            {
                File.Delete(dockerfilePath);
            }

            foreach (var buildOutput in buildOutputs)
            {
                var os = Convert.ToBoolean(ForLinux) ? "linux" : "windows";
                var dockerfileContent = File.OpenText(Path.GetFullPath(RootDirectory + "/build/dockerfiles/" + os + "/" + buildOutput.ContainerImageName + ".txt")).ReadToEnd();
                File.WriteAllText(dockerfilePath, dockerfileContent);

                var imageTag =
                BuildInformation.ContainerRepoDetails.ContainerImagePrefix.TrimEnd('/')
                + "/"
                + buildOutput.ContainerImageName
                + ":"
                + tagVersion;

                Logger.Info("Image: " + imageTag);
                DockerTasks.DockerBuild(x => x
                            .SetPath(BoldBIOutputDir)
                            .SetFile(dockerfilePath)
                            .SetTag(imageTag )
                            );

                containerImages.Add(imageTag);
                File.Delete(dockerfilePath);
            }

            Logger.Info("Login on container repository: " + BuildInformation.ContainerRepoDetails.ContainerImagePrefix);

            foreach (var command in BuildInformation.ContainerRepoDetails.ContainerRepoLoginCommands)
            {
                ProcessTasks.StartProcess(Powershell, command).AssertWaitForExit();
            }

            Logger.Info("Pushing images to container repository: " + BuildInformation.ContainerRepoDetails.ContainerImagePrefix);
            foreach (var image in containerImages)
            {
                Logger.Info("Image: " + image);
                DockerTasks.DockerPush(x => x
                            .SetName(image)
                            );
            }
        }

        Target PublishContainerImage => _ => _
        .DependsOn(MovePublishedProjects)
        .Executes(() =>
        {
            new Build().BuildAndPushContainerImage(BuildVersion);
        });
    }
}