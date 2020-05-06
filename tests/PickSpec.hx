package ;

import be.types.Pick;

@:asserts
class PickSpec {

    public function new() {}

    public function testPick_functionType() {
        var p:Pick<String->String> = Foo;

        asserts.assert( p('foooooo') == 'str: foooooo' );

        p = Std;

        asserts.assert( p('foooooo') == 'foooooo' );

        return asserts.done();
    }

    public function testPick_functionEreg() {
        var p:Pick<String->String, ~/echoStr(ing)?/i> = Bar;

        asserts.assert( p('bar') == 'ECHO: bar' );

        return asserts.done();
    }

    public function testPick_metadataEreg() {
        var p:Pick<Int->Int->Int, ~/@:op\([a-z ]+\+[a-z ]+\)/i> = Baz;

        asserts.assert( p(4, 4) == 8 );

        return asserts.done();
    }

}

class Foo {

    public static function echo(str:String):String {
        return 'str: $str';
    }

}

class Bar {

    public static function bluff(str:String):String {
        throw str;
        return str;
    }

    public static function echoStr(str:String):String {
        return 'ECHO: $str';
    }

    public static function bluffy(str:String):String {
        throw str;
        return str;
    }

}

class Baz {

    @:op(BLAH + BLAH) public static function bluff(a:String, b:String):String {
        throw a + b;
        return b + a;
    }

    @:op(A+B) public static function add(a:Int, b:Int):Int {
        return a + b;
    }

    public static function bluffy(str:String):String {
        throw str;
        return str;
    }

}