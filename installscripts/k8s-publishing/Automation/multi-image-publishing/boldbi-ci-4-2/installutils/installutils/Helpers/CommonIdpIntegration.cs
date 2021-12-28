using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading;
using installutils.Model;
using Newtonsoft.Json;

namespace installutils.Helpers
{
    class CommonIdpIntegration
    {
        public static void CommonIdpSetup(string ExtractedPath)
        {
            var installedDir = "/var/www/bold-services/";
            var productJsonPath = "application/app_data/configuration/product.json";
            var biProductJsonFile = Path.GetFullPath(productJsonPath);
            var reportsProductJsonFile = Path.GetFullPath(Path.Combine(installedDir, productJsonPath));

            Products biProductData = JsonConvert.DeserializeObject<Products>(File.ReadAllText(biProductJsonFile));
            Products reportsProductData = JsonConvert.DeserializeObject<Products>(File.ReadAllText(reportsProductJsonFile));
            Version reportsIdpVersion = new Version(reportsProductData.BoldProducts[0].IDPVersion);
            Version biIdpVersion = new Version(biProductData.BoldProducts[0].IDPVersion);

            var moveIdp = reportsIdpVersion.CompareTo(biIdpVersion);

            if (moveIdp < 0)
            {
                File.WriteAllText($"{ExtractedPath}/idp-Version-check.txt", "true");
            }

            InternalAppUrl internalAppUrl = new InternalAppUrl();
            List<BoldProduct> boldProducts = new List<BoldProduct>();

            internalAppUrl.Idp = reportsProductData.InternalAppUrl.Idp;
            internalAppUrl.Bi = reportsProductData.InternalAppUrl.Idp.TrimEnd('/') + "/bi";
            internalAppUrl.BiDesigner = reportsProductData.InternalAppUrl.Idp.TrimEnd('/') + "/bi/designer";
            internalAppUrl.Reports = reportsProductData.InternalAppUrl.Reports;
            internalAppUrl.ReportsService = reportsProductData.InternalAppUrl.ReportsService;

            BoldProduct boldProductDetailsReports = new BoldProduct
            {
                Name = "BoldReports",
                SetupName = "BoldReports_EnterpriseReporting",
                Version = reportsProductData.BoldProducts[0].Version,
                IDPVersion = moveIdp < 0 ? biProductData.BoldProducts[0].IDPVersion : reportsProductData.BoldProducts[0].IDPVersion,
                IsCommonLogin = true
            };

            boldProducts.Add(boldProductDetailsReports);

            BoldProduct boldProductDetailsBI = new BoldProduct
            {
                Name = "BoldBI",
                SetupName = "BoldBIEnterpriseEdition",
                Version = biProductData.BoldProducts[0].Version,
                IDPVersion = biProductData.BoldProducts[0].IDPVersion,
                IsCommonLogin = true
            };

            boldProducts.Add(boldProductDetailsBI);

            Products products = new Products
            {
                InternalAppUrl = internalAppUrl,
                BoldProducts = boldProducts
            };

            var updatedProductData = JsonConvert.SerializeObject(products, Formatting.Indented);

            if (File.Exists(reportsProductJsonFile))
            {
                File.Delete(reportsProductJsonFile);
            }

            File.WriteAllText(reportsProductJsonFile, updatedProductData);
        }

        public static void ExecuteBashCommand(string command)
        {
            command = command.Replace("\"", "\"\"");

            Process process = new Process();
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.WindowStyle = ProcessWindowStyle.Hidden;
            startInfo.FileName = "/bin/bash";
            startInfo.Arguments = "-c \"" + command + "\"";
            process.StartInfo = startInfo;
            process.Start();
        }
    }
}
