package ;

import be.types.Pick;
import be.types.Resolve.resolve;

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

    public function testPick_typedefClassRedirection() {
        var p:StringParser = Std;

        asserts.assert( p(' 100 ') == 100 );

        p = Foo;

        asserts.assert( p('hello') == ('h'.code + 'e'.code + 'l'.code + 'l'.code + 'o'.code)  );

        return asserts.done();
    }

    public function testPick_abstract() {
        var a:Qux = 10;
        var p:Pick<Int->Int->Int, ~/@:op\([a-z ]+\+[a-z ]+\)/i> = Qux;

        asserts.assert( p(a, 10) == 20 );

        return asserts.done();
    }

    public function testPick_typedefAbstractRedirection() {
        var a:Qux = 10;
        var p:AbstractAdder = Qux;

        asserts.assert( p(a, 10) == 20 );

        return asserts.done();
    }

}

typedef StringParser = Pick<String->Int, ~/(parse|mk)Int/>;
typedef AbstractAdder = Pick<Int->Int->Int, ~/@:op\([a-z ]+\+[a-z ]+\)/i>;

class Foo {

    public static function echo(str:String):String {
        return 'str: $str';
    }

    public static function mkInt(string:String):Int {
        var total = 0;
        for (i in 0...string.length) total += string.charCodeAt(i);
        return total;
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

abstract Qux(Int) from Int to Int {

    private var self(get, never):Int;
    @:to private inline function get_self():Int return this;

    @:op(A + B) public static inline function addFloat(a:Qux, b:Float):Qux {
        throw 'Not implemented';
        return a;
    }

    @:op(A + B) public static inline function addInt(a:Qux, b:Int):Qux {
        return a.self + b;
    }

    @:op(A + B) public static inline function addString(a:Qux, b:String):Qux {
        var total = 0;
        for (i in 0...b.length) total += b.charCodeAt(i);
        return a.self + total;
    }

}