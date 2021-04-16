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

    public static macro function resolve<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        if (Debug && CoerceVerbose) {
            trace( 'start: resolve property' );
            trace( expr.toString(), expr.pos );
        }
        
        var task = Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() );
        var result:Expr = macro @:pos(expr.pos) be.types.ResolveProperty.fromAny($e{Resolver.handleTask(task)});

        if (Debug && CoerceVerbose) {
            trace( result.toString() );
        }

        return result;
    }

    @:noCompletion @:from public static macro function catchAll<Out>(expr:Expr):ExprOf<Out> {
        if (Debug && CoerceVerbose) {
            trace( 'start: catchall property' );
            trace( expr.toString(), expr.pos );
        }

        var type = expr.typeof().sure();

        switch type {
            case TAbstract(_.get() => {name:"ResolveProperty" }, _): 
                return expr;

            case x:
                if (Debug && CoerceVerbose) trace( x );
        }

        var task = Resolver.determineTask( expr, type, Context.getExpectedType() );
        var result:Expr = macro @:pos(expr.pos) be.types.ResolveProperty.fromAny($e{Resolver.handleTask(task)});

        if (Debug && CoerceVerbose) {
            trace( result.toString() );
        }

        return result;
    }

    /*@:from*/ @:noCompletion public static inline function fromAny<T>(v:T):ResolveProperty<T, ~//i, ~//i> return (cast v:ResolveProperty<T, ~//i, ~//i>);

}