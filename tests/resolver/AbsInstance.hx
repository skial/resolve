package resolver;

import be.types.Resolve;

@:asserts
class AbsInstance {

    public function new() {}

    public function test() {
        var a = new AbstractFromInstanceHelper(10);
        var r:Resolve<String->AbstractFromInstanceHelper, ~//, ~//> = a;

        asserts.assert( r('foo').value == 3 );

        return asserts.done();
    }

}

abstract AbstractFromInstanceHelper(Int) {

    public var value(get, never):Int;
    private function get_value() return this;

    public inline function new(v) this = v;

    // skipped by resolve
    @:from public static function fromInt(v:Int):AbstractFromInstanceHelper {
        throw 'v: $v should not have been selected.';
        return new AbstractFromInstanceHelper(v);
    }

    // skipped by resolve
    @:from public static function fromStr(v:String) {
        throw 'v: $v should not have been selected.';
        return new AbstractFromInstanceHelper(v.length);
    }

    public function len(str:String):AbstractFromInstanceHelper {
        return new AbstractFromInstanceHelper(str.length);
    }

}