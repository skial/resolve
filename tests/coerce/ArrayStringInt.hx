package coerce;

import be.types.Resolve.coerce;

@:asserts
class ArrayStringInt {

    public function new() {}

    @:variant('100', [100])
    @:variant('010', [10])
    @:variant('-10', [-10])
    @:variant('0xff', [255])
    public function test(input:String, expected:Array<Int>) {
        var ints:Array<Int> = coerce(input);
        asserts.assert( '' + ints == '' + expected );

        return asserts.done();
    }

}