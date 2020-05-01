package be.types;

import haxe.Constraints.Function;

#if (eval || macro)
import haxe.macro.*;
import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Expr.ComplexType;
import be.coerce.Errors;
import be.macros.Resolver;
import be.coerce.Metadata;
import be.coerce.ResolveTask;

using haxe.macro.Context;
using tink.CoreApi;
using tink.MacroApi;
#end
using StringTools;

abstract Method<T:Function>(Function) from Function to Function {
    public inline function new(v) this = v;
    @:noCompletion public inline function get():T return cast this;

    @:from public static function of<T:Function>(v:T):Method<T> return new Method(v);
    @:from public static function fromResolve<T:Function>(v:Resolve<T, ~//>):Method<T> {
        return new Method(v.get());
    }
    @:to public function toResolve():Resolve<T, ~//i> return cast this;
}

@:callable @:notNull abstract Resolve<T:Function, @:const R:EReg>(T) to T {

    @:noCompletion public inline function get():T return this;
    @:from private static inline function fromFunction<T:Function>(v:T):Resolve<T, ~//i> return (cast v:Resolve<T, ~//i>);

    public static macro function resolve<In, Out:Function>(expr:ExprOf<Class<In>>):ExprOf<Out> {
        var result = null;
        switch Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() ) {
            case SearchMethod(signature, module, statics, e, ereg): 
                Resolver.findMethod(signature, module, statics, ereg).handle( function (o) switch o {
                    case Success(matches):
                        if (matches.length > 0) {
                            result = e.field( matches[matches.length - 1].name );

                        } else {
                            Context.fatalError( NoMatches, e.pos );

                        }

                    case Failure(error): 
                        Context.fatalError( error.message, error.pos );

                } );

            case _: 
                Context.fatalError( UseCoerce, expr.pos );

        }
        if (result == null) Context.fatalError( TotalFailure, expr.pos );
        #if (debug && coerce_verbose)
        trace(result.toString());
        #end
        return result;
    }

    public static macro function coerce<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        var result = null;
        switch Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() ) {
            case ConvertValue(input, output, value): 
                Resolver.convertValue(input, output, value).handle( function(o) switch o {
                    case Success(expr): result = expr;
                    case Failure(error): Context.fatalError( error.message, error.pos );
                } );

            case _: 
                Context.fatalError( UseResolve, expr.pos );
        }
        if (result == null) Context.fatalError( TotalFailure, expr.pos );
        #if (debug && coerce_verbose)
        trace(result.toString());
        #end
        return result;
    }

    @:from private static macro function catchAll<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        var task = Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() );
        var result = null;
        switch task {
            case ConvertValue(input, output, value): 
                Resolver.convertValue(input, output, value).handle( function(o) switch o {
                    case Success(expr): result = expr;
                    case Failure(error): Context.fatalError( error.message, error.pos );
                } );

            case SearchMethod(signature, module, statics, e, ereg): 
                Resolver.findMethod(signature, module, statics, ereg).handle( function(o) switch o {
                    case Success(matches):
                        if (matches.length > 0) {
                            result = e.field( matches[matches.length - 1].name );

                        } else {
                            Context.fatalError( NoMatches, e.pos );

                        }

                    case Failure(error):
                        Context.fatalError( error.message, error.pos );

                } );

        }
        if (result == null) Context.fatalError( TotalFailure, expr.pos );
        #if (debug && coerce_verbose)
        trace(result.toString());
        #end
        return result;
    }

}