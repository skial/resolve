package coerce;

import be.types.Resolve.coerce;

@:asserts
class ArrayArray {

    public function new() {}

    @:variant(['100', '10', '1'], [100, 10, 1])
    @:variant(['010'], [10])
    @:variant(['-10'], [-10])
    @:variant(['0xff'], [255])
    public function test(input:Array<String>, expected:Array<Int>) {
        var ints:Array<Int> = coerce(input);
        asserts.assert( '' + ints == '' + expected );

        return asserts.done();
    }

}