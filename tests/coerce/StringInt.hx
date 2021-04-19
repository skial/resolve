package coerce;

import be.types.Resolve.coerce;

@:asserts
class StringInt {

    public function new() {}

    @:variant('100', 100)
    @:variant('010', 10)
    @:variant('-10', -10)
    @:variant('0xff', 255)
    public function test(input:String, expected:Int) {
        var int:Int = coerce(input);
        asserts.assert( int == expected );

        return asserts.done();
    }

}