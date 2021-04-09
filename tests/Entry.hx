package ;

import tink.unit.TestBatch;
import tink.testrunner.Runner;

class Entry {

    public static function main() {
        Runner.run(TestBatch.make([
            new coerce.IntString(),
            new coerce.FloatString(),
            new coerce.StringBool(),
            new coerce.StringInt(),
            new coerce.StringFloat(),
            new coerce.ArrayStringInt(),
            new coerce.ArrayArray(),
            new coerce.ArrayArrayOfAbstract(),
            new resolver.StringSpec(),
            new resolver.ReassignSpec(),
            new resolver.ClassSpec(),
            new resolver.GenericCaller(),
            new resolver.MetaSpec(),
            new resolver.Redefined(),
            new resolver.AbsStatic(),
            new resolver.AbsStaticFindField(),
            new resolver.AbsInstance(),
            new resolver.AbsInstanceFindField(),
            new resolver.AbsInstanceWithMeta(),
            new resolver.AbsInstanceMatchStatic(),
            new CoerceSpec(),
            new ResolveSpec(),
            new PickSpec(),
            // Resolving properties
            new resolver.ClassPropertySpec(),
        ])).handle( Runner.exit );
    }

}