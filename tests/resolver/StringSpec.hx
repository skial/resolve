package resolver; // package `resolve` gets confused? with the method `resolve`...

import be.types.Resolve;
import be.types.Resolve.resolve;

@:asserts
class StringSpec {

    public function new() {}

    public function testFromStaticClass() {
        var r:Resolve<String->String, ~//, ~//> = resolve(Foo);

        asserts.assert( r('echo1') == 'echo1:echo1' );

        return asserts.done();
    }

    public function testFromStaticClass_typeless() {
        var r:String->String = resolve(Foo);

        asserts.assert( r('echo2') == 'echo2:echo2' );

        return asserts.done();
    }

    public function testFromStaticClass_methodless() {
        var r:Resolve<String->String, ~//, ~//> = Foo;

        asserts.assert( r('echo3') == 'echo3:echo3' );

        return asserts.done();
    }

}

class Foo {

    public static function echo(str:String):String {
        return str + ':' + str;
    }

}