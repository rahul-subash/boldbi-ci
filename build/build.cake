#addin nuget:?package=Cake.Git&version=1.0.1
#addin "Cake.Powershell"
#addin nuget:?package=Cake.AWS.S3
#addin nuget:?package=Cake.AWS.CloudFront
#addin nuget:?package=Cake.AzureStorage
#tool "nuget:?package=BuildWebCompiler&version=1.11.375"
#addin nuget:?package=Cake.Json&version=6.0.1
#addin nuget:?package=Newtonsoft.Json&version=9.0.1
#addin "nuget:https://www.nuget.org/api/v2?package=Cake.Http"
#addin "Cake.Npm" 
#addin nuget:?package=Cake.FileHelpers&version=4.0.1
#addin "Cake.FileHelpers"


var projectFramework = "netcoreapp3.1";
var framework = Argument("framework", projectFramework);
var target = Argument("target", "Publish");
var outputPathArgs = Argument("outputpath","");
var studioVersion=Argument("studio_version", "1.0.0");
string copyrightInfo = "[assembly: AssemblyCopyright(\"Copyright (c) 2001-" + DateTime.Now.Year + " Syncfusion. Inc,\")]";
var configuration = Argument("configuration", "Release");
var currentDirectory = MakeAbsolute(Directory("../"));
var applicationPath = currentDirectory + @"/installutils";
var outputDirectory = currentDirectory + @"/output";
var projectName = "installutils";

if(String.IsNullOrWhiteSpace(outputPathArgs) == false)
{
	outputDirectory = outputPathArgs;
}

//////////////////////////////////////////////////////////////////////
// TASKS
//////////////////////////////////////////////////////////////////////

Task("Clean")
    .WithCriteria(c => HasArgument("rebuild"))
    .Does(() =>
{
    CleanDirectory($"{applicationPath}/installutils/bin/{configuration}");
});

Task("Build")
    .IsDependentOn("Clean")
    .Does(() =>
{
    DotNetCoreBuild($"{applicationPath}/installutils.sln", new DotNetCoreBuildSettings
    {
        Configuration = configuration,
    });
});

Task("CopyrightandVersion")
  .Does(() =>
{
	var filePathPattern = "../**/*AssemblyInfo.cs";

	ReplaceRegexInFiles(filePathPattern, @"[\d]{1,2}\.[\d]{1}\.[\d]{1}\.[\d]{1,4}", studioVersion);
	ReplaceRegexInFiles(filePathPattern, @"\[assembly:\s*AssemblyCopyright\s*.*?\]", copyrightInfo);
	ReplaceRegexInFiles(filePathPattern, @"AssemblyCompany\s*.*", "AssemblyCompany(\"Syncfusion, Inc.\")]");
});

Task("CopyrightandVersion.V2")
	.Does(()=>
	{
		Information("currentDirectory: "+ currentDirectory);
		var propsFile = currentDirectory + "/Directory.Build.props";
		XmlPoke(propsFile, "//Version", studioVersion);
		XmlPoke(propsFile, "//Copyright", "Copyright (c) 2001-"+ DateTime.Now.Year +" Syncfusion, Inc.");
	})
	.OnError(exception=>
	{
		throw new Exception(String.Format("Error while updating assembly info"));
	});

Task("Publish")
	.IsDependentOn("Clean")
	.IsDependentOn("CopyrightandVersion")
	.IsDependentOn("CopyrightandVersion.V2")
	.IsDependentOn("Build")
	.Does(()=>
	{
		var publishProfile =  projectName + "-" + configuration;
		var publishSettings = new DotNetCorePublishSettings
		{
			Configuration = configuration,
			OutputDirectory = outputDirectory + "/" + projectName,
			MSBuildSettings = new DotNetCoreMSBuildSettings().WithProperty("PublishProfile", publishProfile)
		};
		Information("==================");
		Information("Started publishing "+ projectName);
		Information(publishSettings.Configuration);
		Information(publishProfile);
		Information("==================");
		DotNetCorePublish($"{applicationPath}/installutils/installutils.csproj", publishSettings);
	})
	.OnError(exception=>
	{
		throw new Exception(String.Format("Error while publishing projects"));
	});

Task("Test")
    .IsDependentOn("Build")
    .Does(() =>
{
    DotNetCoreTest($"{applicationPath}/installutils.sln", new DotNetCoreTestSettings
    {
        Configuration = configuration,
        NoBuild = true,
    });
});

//////////////////////////////////////////////////////////////////////
// EXECUTION
//////////////////////////////////////////////////////////////////////

RunTarget(target);