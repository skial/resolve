package resolver;

import be.types.Resolve;
import be.types.Resolve.resolve;

@:asserts
class AbsInstanceFindField {

    public function new() {}

    public function test() {
        var a:AbsInstanceHelper = new AbsInstanceHelper(10);
        var r:Resolve<String->String, ~/shout/i, ~//> = a;

        asserts.assert( r('foo') == 'FOO' );
        
        return asserts.done();
    }

}

abstract AbsInstanceHelper(Int) {

    public inline function new(v) this = v;

    public static function echo(v:String):String {
        throw 'v: $v should not be selected.';
        return v;
    }

    public function shout(v:String):String {
        return v.toUpperCase();
    }

    public function shoutLen(v:String):Int {
        throw 'Method shoutLen should not be selected';
        return v.length;
    }

}