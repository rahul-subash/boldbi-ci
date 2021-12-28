using System;
using System.IO;
using System.Xml;
using installutils.Helpers;

namespace ExtractAppData
{
    class Program
    {
        static void Main(string[] args)
        {
            try
            {
                if (args.Length == 2 && args[0].Contains("common_idp_setup"))
                {
                    CommonIdpIntegration.CommonIdpSetup(args[1].TrimStart().TrimEnd());
                }
                else if (args.Length == 2 && args[0].Contains("upgrade_version"))
                {
                    UpdateProductVersion.UpdateVersion(args[1].TrimStart().TrimEnd());
                }
                else if (args.Length == 3 && args[0].Contains("bing_map_config_migration"))
                {
                    HandleBingMapMigration.BingMapConfigMigration(args[1].TrimStart().TrimEnd(), args[2].TrimStart().TrimEnd());
                }
                else
                {
                    var sourcePath = Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory + "/app_data");
                    var destPath = string.Empty;
                    if (args.Length != 0)
                    {
                        destPath = Path.GetFullPath(args[0]);
                    }
                    else
                    {
                        destPath = "/application/app_data";
                    }

                    //Write Base URL to config file
                    var baseUrl = Environment.GetEnvironmentVariable("APP_BASE_URL");
                    var isInvalidConfigBaseUrl = false;

                    if (File.Exists(destPath + "/configuration/config.xml"))
                    {
                        XmlDocument doc = new XmlDocument();
                        XmlTextReader reader = new XmlTextReader(destPath + "/configuration/config.xml");
                        reader.Read();
                        doc.Load(reader);
                        foreach (XmlNode a in doc.GetElementsByTagName("SystemSettings"))
                        {
                            foreach (XmlNode b in a.SelectNodes("InternalAppUrls"))
                            {
                                isInvalidConfigBaseUrl = b.SelectNodes("Idp").Item(0).InnerText.StartsWith("http://localhost") ||
                                b.SelectNodes("Bi").Item(0).InnerText.StartsWith("http://localhost") ||
                                b.SelectNodes("BiDesigner").Item(0).InnerText.StartsWith("http://localhost");
                            }
                        }
                    }

                    if (!File.Exists(destPath + "/configuration/product.json"))
                    {
                        string json = File.ReadAllText(sourcePath + "/configuration/product.json");
                        dynamic jsonObj = Newtonsoft.Json.JsonConvert.DeserializeObject(json);

                        if (!string.IsNullOrWhiteSpace(baseUrl)
                            && !(baseUrl.Contains('<') && baseUrl.Contains('>'))
                            && (!File.Exists(destPath + "/configuration/config.xml") || isInvalidConfigBaseUrl))
                        {
                            Console.WriteLine("BaseUrl: " + baseUrl);
                            jsonObj["InternalAppUrl"]["Idp"] = baseUrl;
                            jsonObj["InternalAppUrl"]["Bi"] = baseUrl + "/bi";
                            jsonObj["InternalAppUrl"]["BiDesigner"] = baseUrl + "/bi/designer";
                        }

                        string output = Newtonsoft.Json.JsonConvert.SerializeObject(jsonObj, Newtonsoft.Json.Formatting.Indented);
                        CloneDirectory(sourcePath + "/configuration", destPath + "/configuration");
                        File.WriteAllText(destPath + "/configuration/product.json", output);
                    }

                    //Write user input on optional libraries in text file

                    if (Directory.Exists(destPath + "/optional-libs"))
                    {
                        Console.WriteLine($"Deleting {destPath}/optional-libs");
                        Directory.Delete(destPath + "/optional-libs", true);
                    }

                    CommonIdpIntegration.ExecuteBashCommand($"cp -a {sourcePath}/optional-libs {destPath}");

                    var optionalLibs = Environment.GetEnvironmentVariable("INSTALL_OPTIONAL_LIBS");
                    if (!string.IsNullOrWhiteSpace(optionalLibs) && !(optionalLibs.Contains('<') && optionalLibs.Contains('>')))
                    {
                        File.WriteAllText(destPath + "/optional-libs/optional-libs.txt", optionalLibs);
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Exception: " + ex.Message);
            }
        }

        private static void CloneDirectory(string source, string dest)
        {
            if (!Directory.Exists(dest))
            {
                Directory.CreateDirectory(dest);
            }

            foreach (var directory in Directory.GetDirectories(source))
            {
                string dirName = Path.GetFileName(directory);
                CloneDirectory(directory, Path.Combine(dest, dirName));
            }

            foreach (var file in Directory.GetFiles(source))
            {
                File.Copy(file, Path.Combine(dest, Path.GetFileName(file)));
            }
        }
    }
}