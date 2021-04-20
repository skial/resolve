package ;

import be.types.Resolve;

@:asserts
class PassThrough {

    public function new() {}

    public function test() {
        var string = 'hello world';
        var singleType:Resolve<String> = string;

        asserts.assert( singleType == string );

        var method = function (v:String):String return '$v$v';
        var funcType:Resolve<String->String> = method;

        asserts.assert( funcType(string) == string + string );

        return asserts.done();
    }

}