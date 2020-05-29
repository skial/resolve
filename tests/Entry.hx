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
            new CoerceSpec(),
            new ResolveSpec(),
            new PickSpec(),
        ])).handle( Runner.exit );
    }

}