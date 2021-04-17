package resolver;

import be.types.ResolveProperty;

typedef Left<T> = ResolveProperty<T, ~/left([a-z]*)/i, ~/@:left/i>;
typedef Right<T> = ResolveProperty<T, ~//i, ~/@:right/i>;

@:asserts
class GenericPropertySpec {

    public function new() {}

    public function testGenericResolve() {
        var a = new GenericPropertyHelper(55.5);
        asserts.assert( singleLhs(a) == '55.5' );
        /**
            As the only filter on `Right<T>` is a meta `@:right`, both
            statics in `GenericPropertyHelper` are matched. But the first field
            to unify with the type parameter of `Right<T>`, LiFo order, so in 
            this case `defaultRightInt` is selected.
        **/
        asserts.assert( singleRhs(GenericPropertyHelper) == '10' );
        asserts.assert( singleRhsHint(GenericPropertyHelper) == '0.1' );
        asserts.assert( combine(a, GenericPropertyHelper) == '55.5 + 0.1' );
        return asserts.done();
    }

    @:generic public static function singleLhs<T>(lhs:Left<T>):String {
        return Std.string(lhs);
    }

    @:generic public static function singleRhs<T>(lhs:Right<T>):String {
        return Std.string(lhs);
    }

    @:generic public static function singleRhsHint<T:Float>(lhs:Right<T>):String {
        return Std.string(lhs);
    }

    @:generic public static function combine<T>(a:Left<T>, b:Right<T>):String {
        return Std.string(a) + ' + ' + Std.string(b);
    }

}

class GenericPropertyHelper {

    public var lefty:Float;
    @:right public static var defaultRightFloat:Float = 0.1;
    @:right public static var defaultRightInt:Int = 10;

    public function new(l:Float) {
        lefty = l;
    }

}