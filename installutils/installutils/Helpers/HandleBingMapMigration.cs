using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Xml;
using System.Xml.Linq;

namespace installutils.Helpers
{
    class HandleBingMapMigration
    {
        public static void BingMapConfigMigration(string bingMapEnable, string bingMapApiKey)
        {
            var installedDir = "/var/www/bold-services/";
            var configfile = "application/app_data/configuration/config.xml";
            string configXML = Path.GetFullPath(Path.Combine(installedDir, configfile));

            if (File.Exists(configXML))
            {
                XmlDocument xmlDoc = new XmlDocument();
                xmlDoc.Load(configXML);
                xmlDoc.DocumentElement.AppendChild(xmlDoc.CreateElement("Designer")).AppendChild(xmlDoc.CreateElement("Widgets")).AppendChild(xmlDoc.CreateElement("BingMap"));

                XmlElement EnableElement = xmlDoc.CreateElement("Enable");
                EnableElement.InnerText = bingMapEnable.TrimStart('"').TrimEnd('"');

                XmlElement KeyElement = xmlDoc.CreateElement("Key");
                KeyElement.InnerText = bingMapApiKey.TrimStart('"').TrimEnd('"');

                XmlNode BingMapNode = xmlDoc.SelectSingleNode("SystemSettings/Designer/Widgets/BingMap");
                BingMapNode.AppendChild(EnableElement);
                BingMapNode.AppendChild(KeyElement);
                xmlDoc.Save(configXML);
            }
            else
            {
                Console.WriteLine($"{configXML} does not exist.");
            }
        }
    }
}
