package nz.co.codec.flexorm.util
{
    import mx.utils.StringUtil;

    public class StringUtils
    {
        public static function underscore(name:String):String
        {
            var retval:String = "";
            for (var i:int = 0; i < name.length; i++)
            {
                if (i > 0 && isUpperCase(name, i))
                {
                    retval += "_" + name.charAt(i).toLowerCase();
                }
                else if (i > 0 && isNumber(name, i))
                {
                    retval += "_" + name.charAt(i);
                }
                else
                {
                    retval += name.charAt(i);
                }
            }
            return retval;
        }

        public static function camelCase(name:String):String
        {
            var retval:String = "";
            for (var i:int = 0; i < name.length; i++)
            {
                if (i > 0 && name.charAt(i) == "_")
                {
                    retval += name.charAt(++i).toUpperCase();
                }
                else
                {
                    retval += name.charAt(i);
                }
            }
            return retval;
        }

        public static function startLowerCase(str:String):String
        {
            return str.substr(0,1).toLowerCase() + str.substr(1);
        }

        public static function isLowerCase(str:String, pos:int = 0):Boolean
        {
            if (pos >= str.length) return false;
            var char:int = str.charCodeAt(pos);
            return (char > 96 && char < 123);
        }

        public static function isUpperCase(str:String, pos:int = 0):Boolean
        {
            if (pos >= str.length) return false;
            var char:int = str.charCodeAt(pos);
            return (char > 64 && char < 91);
        }

        public static function isNumber(str:String, pos:int = 0):Boolean
        {
            if (pos >= str.length) return false;
            var char:int = str.charCodeAt(pos);
            return (char > 47 && char < 58);
        }

        public static function parseBoolean(str:String, defaultValue:Boolean):Boolean
        {
            if (str == null)
                return defaultValue;

            switch (StringUtil.trim(str))
            {
                case "":
                    return defaultValue;
                    break;
                case "true":
                    return true;
                    break;
                case "false":
                    return false;
                    break;
                default:
                    throw new Error("Cannot parse Boolean from '" + str + "'");
            }
        }

    }
}