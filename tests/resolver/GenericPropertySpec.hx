package resolver;

import be.types.ResolveProperty;

typedef Left<T> = ResolveProperty<T, ~/left([a-z]*)/i, ~/@:left/i>;
typedef Right<T> = ResolveProperty<T, ~//i, ~/@:right/i>;

@:asserts
class GenericPropertySpec {

    public function new() {}

    public function testGenericResolve() {
        var a = new GenericPropertyHelper(55.5);
        //asserts.assert( combine(a, 0.1) == '55.5 + 0.1' );
        asserts.assert( combine(a, GenericPropertyHelper) == '55.5 + 0.1' );
        return asserts.done();
    }

    @:generic public static function combineHint<T>(a:Left<T>, b:Right<T>):String {
        return Std.string(a) + ' + ' + Std.string(b);
    }

    @:generic public static function combine<T>(a:Left<T>, b:Right<T>):String {
        return Std.string(a) + ' + ' + Std.string(b);
    }

}

class GenericPropertyHelper {

    public var lefty:Float;
    @:right public static var defaultRightInt:Int = 10;
    @:right public static var defaultRightFloat:Float = 0.1;

    public function new(l:Float) {
        lefty = l;
    }

}