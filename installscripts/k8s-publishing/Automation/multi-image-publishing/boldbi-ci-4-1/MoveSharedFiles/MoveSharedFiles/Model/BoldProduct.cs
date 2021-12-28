using System;
using System.Collections.Generic;
using System.Text;

namespace installutils.Model
{
    public class Products
    {
        public InternalAppUrl InternalAppUrl
        {
            get;
            set;
        }

        public List<BoldProduct> BoldProducts
        {
            get;
            set;
        }
    }

    public class BoldProduct
    {
        public string Name
        {
            get;
            set;
        }

        public string SetupName
        {
            get;
            set;
        }

        public string Version
        {
            get;
            set;
        }

        public string IDPVersion
        {
            get;
            set;
        }

        public bool IsCommonLogin
        {
            get;
            set;
        }
    }

    public class InternalAppUrl
    {
        public string Idp { get; set; }

        public string Bi { get; set; }

        public string BiDesigner { get; set; }

        public string Reports { get; set; }

        public string ReportsService { get; set; }
    }
}