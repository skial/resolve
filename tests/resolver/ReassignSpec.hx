package resolver;

import be.types.Resolve;
import be.types.Resolve.resolve;

import tink.unit.AssertionBuffer;

@:asserts
class ReassignSpec {

    public function new() {}

    public function test() {
        var r:Resolve<String->String, ~//, ~//> = resolve(Std);

        asserts.assert( r('foo') == 'foo' );

        r = ReassignSpec;

        asserts.assert( r('foo') == 'foofoo' );

        r = this;

        asserts.assert( r('foo') == 'FOO' );

        return asserts.done();
    }

    public static inline function echoish(v:String):String {
        return v + v;
    }

    private function shout(v:String):String {
        return v.toUpperCase();
    }

}