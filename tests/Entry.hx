package ;

import tink.unit.TestBatch;
import tink.testrunner.Runner;

class Entry {

    public static function main() {
        Runner.run(TestBatch.make([
            new CoerceSpec(),
            new ResolveSpec(),
        ])).handle( Runner.exit );
    }

}