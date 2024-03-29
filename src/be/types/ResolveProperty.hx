package be.types;

#if (eval || macro)
import haxe.macro.Expr;
import haxe.macro.Defines;
import be.resolve.macros.Resolver;

using haxe.macro.Context;
using tink.MacroApi;
#end
using StringTools;

@:notNull abstract ResolveProperty<T, @:const R:EReg, @:const M:EReg>(T) to T {

    @:noCompletion public inline function get():T return this;

    @:noCompletion @:from public static macro function resolve<Out>(expr:Expr):ExprOf<Out> {
        var debug = Debug && ResolveVerbose;
        if (debug) {
            trace( 'resolve property' );
            trace( expr.toString(), expr.pos );
        }

        var type = expr.typeof().sure();

        switch type {
            case TAbstract(_.get() => {name:"ResolveProperty" }, _): 
                if (debug) {
                    trace('already resolved');
                }
                return macro $e{expr}.get();

            case x:
                if (debug) trace( x );
        }

        var task = Resolver.determineTask( expr, type, Context.getExpectedType() );
        var e = Resolver.handleTask(task);
        var result:Expr = macro @:pos(expr.pos) be.types.ResolveProperty.seal($e);

        if (debug) {
            trace( result.toString() );
        }

        return result;
    }

    @:noCompletion public static inline function seal<T>(v:T):ResolveProperty<T, ~//i, ~//i> return (cast v:ResolveProperty<T, ~//i, ~//i>);

}