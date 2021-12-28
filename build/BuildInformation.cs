using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using NuGet.Packaging;
using Octokit;
using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace BoldBICI
{
    public class BuildInformation
    {
        public GitCredentials GitCredentials { get; set; }
        public List<Projects> Projects { get; set; }
        public ContainerRepoDetails ContainerRepoDetails { get; set; }
        public Versioning Versioning { get; set; }
        public LinuxMachineDetails LinuxMachineDetails { get; set; }
        public List<string> optionalassemblies { get; set; }
    }

    public class GitCredentials
    {
        public string Username { get; set; }
        public string Password { get; set; }
    }

    public class ContainerRepoDetails
    {
        public string ContainerImagePrefix { get; set; }
        public List<string> ContainerRepoLoginCommands { get; set; }
    }

    public class Projects
    {
        public string Name { get; set; }
        public string Repo { get; set; }
        public string Branch { get; set; }
        public int BuildOrder { get; set; }
        public string BuildCmd { get; set; }
        public List<BuildOutputs> BuildOutputs { get; set; }
        public AfterBuild AfterBuild { get; set; }
        public BeforeBuild BeforeBuild { get; set; }
    }

    public class Versioning
    {
        public List<string> Files { get; set; }
    }

    public class AfterBuild
    {
        public List<FileCopyActions> FileCopyActions { get; set; }
    }

    public class BeforeBuild
    {
        public List<FileCopyActions> FileCopyActions { get; set; }
    }

    public class FileCopyActions
    {
        public string SourceDir { get; set; }
        public string DestDir { get; set; }
        public DirType OutputDirType { get; set; }
    }

    public class BuildOutputs
    {
        public string Name { get; set; }
        public string DestDir { get; set; }
        public string SourceDir { get; set; }
        public DirType OutputDirType { get; set; }
        public string ContainerImageName { get; set; }
    }

    public class LinuxMachineDetails
    {
        public string Username { get; set; }
        public string Password { get; set; }
        public string Domain { get; set; }

    }

    [JsonConverter(typeof(StringEnumConverter))]
    public enum DirType
    {
        Output = 0,
        Working
    }
}
