package be.types;

#if (eval || macro)
import haxe.macro.Expr;
import haxe.macro.Defines;
import be.macros.Resolver;

using haxe.macro.Context;
using tink.MacroApi;
#end
using StringTools;

@:notNull abstract ResolveProperty<T, @:const R:EReg, @:const M:EReg>(T) to T {

    @:noCompletion public inline function get():T return this;
    @:from private static inline function fromAny<T>(v:T):ResolveProperty<T, ~//i, ~//i> return (cast v:ResolveProperty<T, ~//i, ~//i>);

    public static macro function resolve<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        if (Debug && CoerceVerbose) {
            trace( 'start: resolve property' );
            trace( expr.toString(), expr.pos );
        }
        
        var task = Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() );
        var result:Expr = Resolver.handleTask(task);

        if (Debug && CoerceVerbose) {
            trace( result.toString() );
        }

        return result;
    }

}