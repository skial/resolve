package coerce;

import be.types.Resolve.coerce;

@:asserts
class ArrayArrayOfAbstract {

    public function new() {}

    @:variant(['100', '10', '1'], ['1'.code, '1'.code, '1'.code])
    @:variant(['010'], ['0'.code])
    @:variant(['-10'], ['-'.code])
    @:variant(['0xff'], ['0'.code])
    public function test(input:Array<String>, expected:Array<AAOAHelper>) {
        var ints:Array<AAOAHelper> = coerce(input);
        asserts.assert( '' + ints == '' + expected );

        return asserts.done();
    }

}

abstract AAOAHelper(Int) from Int to Int {

    public inline function new(v) this = v;

    @:from public static function fromString(v:String) {
        return new AAOAHelper(v.charCodeAt(0));
    }

}