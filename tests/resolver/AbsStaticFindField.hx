package resolver;

import be.types.Resolve;
import be.types.Resolve.resolve;

@:asserts
class AbsStaticFindField {

    public function new() {}

    public function test() {
        var r:Resolve<String->String, ~/shout/i, ~//> = AbsStaticHelper;

        asserts.assert( r('foo') == 'FOO' );
        
        return asserts.done();
    }

}

abstract AbsStaticHelper(Int) {

    public inline function new(v) this = v;

    public static function echo(v:String):String {
        throw 'v: $v should not be selected.';
        return v;
    }

    public static function shout(v:String):String {
        return v.toUpperCase();
    }

}