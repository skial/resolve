package be.types;

import haxe.Constraints.Function;

#if (eval || macro)
import haxe.macro.Expr;
import haxe.macro.Defines;
import be.macros.Resolver;
import be.coerce.ResolveTask;

using haxe.macro.Context;
using tink.MacroApi;
#end
using StringTools;

@:callable @:notNull abstract Resolve<T:Function, @:const R:EReg, @:const M:EReg>(T) to T {

    @:noCompletion public inline function get():T return this;
    @:from private static inline function fromFunction<T:Function>(v:T):Resolve<T, ~//i, ~//i> return (cast v:Resolve<T, ~//i, ~//i>);

    public static macro function resolve<In, Out:Function>(expr:ExprOf<Class<In>>):ExprOf<Out> {
        if (Debug && CoerceVerbose) {
            trace( 'start: resolve' );
            trace( expr.toString(), expr.pos );
        }
        
        var task = Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() );
        var result:Expr = Resolver.handleTask(task);

        if (Debug && CoerceVerbose) {
            trace( result.toString() );
        }

        return result;
    }

    public static macro function coerce<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        if (Debug && CoerceVerbose) {
            trace( 'start: coerce' );
            trace( expr.toString(), expr.pos );
        }

        var task = Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() );
        var result:Expr = Resolver.handleTask(task);

        if (Debug && CoerceVerbose) {
            trace(result.toString());
        }

        return result;
    }

    @:noCompletion @:from public static macro function catchAll<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        if (Debug && CoerceVerbose) {
            trace( 'start: catch all' );
            trace( expr.toString(), expr.pos );
        }

        var task = Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() );
        var result:Expr = Resolver.handleTask(task);

        // Not happy about `cast`ing this...
        result = macro cast $result;

        if (Debug && CoerceVerbose) {
            trace(result.toString());
        }

        return result;
    }

}