package nz.co.codec.flexorm
{
    import flash.errors.SQLError;

    public class EntityError extends Error
    {
        private var _sqlError:SQLError;

        public function EntityError(message:String, sqlError:SQLError=null)
        {
            super(message);
            _sqlError = sqlError;
        }

        public function get sqlError():SQLError
        {
            return _sqlError;
        }

    }
}