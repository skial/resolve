package resolver;

import be.types.Resolve;

@:asserts
class AbsStatic {

    public function new() {}

    public function test() {
        var r:Resolve<String->AbstractFromStaticHelper, ~//, ~//> = AbstractFromStaticHelper;

        asserts.assert( r('foo').value == 3 );

        return asserts.done();
    }

}

abstract AbstractFromStaticHelper(Int) {

    public var value(get, never):Int;
    private function get_value() return this;

    public inline function new(v) this = v;

    @:from public static function fromInt(v:Int):AbstractFromStaticHelper {
        throw 'v: $v should not be selected.';
        return new AbstractFromStaticHelper(v);
    }

    @:from public static function fromStr(v:String) {
        return new AbstractFromStaticHelper(v.length);
    }

}