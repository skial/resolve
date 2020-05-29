package resolver;

import be.types.Resolve;

@:asserts
class AbsInstanceWithMeta {

    public function new() {}

    public function test() {
        var a = new AbstractInstanceWithMetaHelper(10);
        var r:Resolve<String->AbstractInstanceWithMetaHelper, ~//, ~/@:from/> = a;

        asserts.assert( r('foo').value == 3 );

        return asserts.done();
    }

}

abstract AbstractInstanceWithMetaHelper(Int) {

    public var value(get, never):Int;
    private function get_value() return this;

    public inline function new(v) this = v;

    // skipped by resolve
    @:from public static function fromInt(v:Int):AbstractInstanceWithMetaHelper {
        throw 'str: $v should not have been selected.';
        return new AbstractInstanceWithMetaHelper(v);
    }

    // skipped by resolve
    @:from public static function fromStr(v:String) {
        return new AbstractInstanceWithMetaHelper(v.length);
    }

    public function len(str:String):AbstractInstanceWithMetaHelper {
        throw 'str: $str should not have been selected.';
        return new AbstractInstanceWithMetaHelper(str.length);
    }

}