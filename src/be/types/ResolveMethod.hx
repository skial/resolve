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

typedef FoundMethod<T:Function> = ResolveMethod<T, ~//, ~//>;

@:callable @:notNull abstract ResolveMethod<T:Function, @:const R:EReg, @:const M:EReg>(T) to T {

    @:noCompletion public inline function get():T return this;
    @:noCompletion @:from public static inline function fromFunction<T:Function>(v:T):ResolveMethod<T, ~//i, ~//i> return (cast v:ResolveMethod<T, ~//i, ~//i>);
    @:noCompletion public static inline function seal<T:Function>(v:T):FoundMethod<T> return (cast v:FoundMethod<T>);

    public static macro function coerce<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        var debug = Debug && CoerceVerbose;
        if (debug) {
            trace( 'start: coerce' );
            trace( expr.toString(), expr.pos );
        }

        var task = Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() );
        var result:Expr = Resolver.handleTask(task);

        if (debug) {
            trace(result.toString());
        }

        return result;
    }

    @:from public static macro function resolve<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        var debug = Debug && CoerceVerbose;
        if (debug) {
            trace( 'start: resolve' );
            trace( expr.toString(), expr.pos );
        }

        var type = haxe.macro.Context.typeof(expr);

        if (debug) {
            trace( haxe.macro.TypeTools.toString(type) );
        }

        switch type {
            case TType(_.get() => {name:"FoundMethod"}, _):
                if (debug) trace('<already resolved ...>');
                return expr;
            case TAbstract(_.get() => { name:"ResolveMethod"}, _):
                if (debug) trace('<already a resolve ...>');
                return expr;

            case x:
                if (debug) trace( x );
        }

        var wrap:Bool = false;
        var expectedType = Context.getExpectedType();
        var outputType = switch expectedType {
            case TType(_.get() => { type: TAbstract(_.get() => {name:"ResolveMethod"}, params)}, _) | TAbstract(_.get() => { name:"ResolveMethod"}, params):
                wrap = true;
                params[0];

            case x:
                x;
        }

        if (debug) {
            trace( wrap, outputType );
        }
        
        var outputComplex:Null<ComplexType> = Context.toComplexType(outputType);
        var task = Resolver.determineTask( expr, type, expectedType );
        var result:Expr = Resolver.handleTask(task);

        if (wrap && outputComplex != null) result = macro ($e{result}:$outputComplex);
        result = macro @:pos(expr.pos) be.types.ResolveMethod.seal( $result );

        if (debug) {
            trace(result.toString());
        }

        return result;
    }

}