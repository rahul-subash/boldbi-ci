using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading;
using installutils.Model;
using Newtonsoft.Json;

namespace installutils.Helpers
{
    class UpdateProductVersion
    {
        public static void UpdateVersion(string Environment)
        {
            var installedDir = "/var/www/bold-services/";
            var productJsonPath = "application/app_data/configuration/product.json";
            var installedBiProductJsonFile = "/application/app_data/configuration/product.json";
            var biProductJsonFile = "/application/product.json";

            if (Environment.Equals("linux"))
            {
                installedBiProductJsonFile = Path.GetFullPath(Path.Combine(installedDir, productJsonPath));
                biProductJsonFile = Path.GetFullPath(productJsonPath);
            }
            else if (Environment.Equals("docker"))
            {
                installedBiProductJsonFile = Path.GetFullPath(installedBiProductJsonFile);
                biProductJsonFile = Path.GetFullPath(biProductJsonFile);
            }
            
            Products biProductData = JsonConvert.DeserializeObject<Products>(File.ReadAllText(biProductJsonFile));
            Products installedBiProductJsonData = JsonConvert.DeserializeObject<Products>(File.ReadAllText(installedBiProductJsonFile));

            Products products = new Products
            {
                InternalAppUrl = installedBiProductJsonData.InternalAppUrl,
                BoldProducts = biProductData.BoldProducts
            };

            var updatedProductData = JsonConvert.SerializeObject(products, Formatting.Indented);

            if (File.Exists(installedBiProductJsonFile))
            {
                File.Delete(installedBiProductJsonFile);
            }

            File.WriteAllText(installedBiProductJsonFile, updatedProductData);

            Console.WriteLine("Successfully updated product version");
        }
    }
}
