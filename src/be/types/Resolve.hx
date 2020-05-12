package be.types;

import haxe.Constraints.Function;

#if (eval || macro)
import haxe.macro.Type;
import haxe.macro.Expr;
import be.coerce.Errors;
import haxe.macro.Defines;
import be.macros.Resolver;
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
    @:from public static function fromResolve<T:Function>(v:Resolve<T, ~//i, ~//i>):Method<T> {
        return new Method(v.get());
    }
    @:to public function toResolve():Resolve<T, ~//i, ~//i> return cast this;
}

@:callable @:notNull abstract Resolve<T:Function, @:const R:EReg, @:const M:EReg>(T) to T {

    @:noCompletion public inline function get():T return this;
    @:from private static inline function fromFunction<T:Function>(v:T):Resolve<T, ~//i, ~//i> return (cast v:Resolve<T, ~//i, ~//i>);

    public static macro function resolve<In, Out:Function>(expr:ExprOf<Class<In>>):ExprOf<Out> {
        if (Debug && CoerceVerbose) {
            trace( 'start: resolve' );
            trace( expr.toString() );
        }
        
        var result:Expr = null;

        switch Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() ) {
            case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg): 
                Resolver.findMethod(signature, module, statics, e.pos, fieldEReg, metaEReg).handle( function (o) switch o {
                    case Success(matches):
                        if (matches.length == 0) {
                            result = e.field( matches[0].name );

                        } else if (matches.length > 0) {
                            while (matches.length > 0) {
                                var field = matches.pop();

                                if (field.type.unify(signature)) {
                                    result = e.field( field.name );
                                    break;

                                }

                            }

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

        if (Debug && CoerceVerbose) {
            trace(result.toString());
        }

        return result;
    }

    public static macro function coerce<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        if (Debug && CoerceVerbose) {
            trace( 'start: coerce' );
            trace( expr.toString() );
        }

        var result:Expr = null;

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

        if (Debug && CoerceVerbose) {
            trace(result.toString());
        }

        return result;
    }

    @:noCompletion @:from public static macro function catchAll<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        if (Debug && CoerceVerbose) {
            trace( 'start: catch all' );
            trace( expr.toString() );
        }

        var task = Resolver.determineTask( expr, expr.typeof().sure(), Context.getExpectedType() );
        var result:Expr = null;

        switch task {
            case Multiple(tasks):
                var names:Array<String> = [];
                var methods:Array<{name:String, type:Type, hits:Array<{sig:Type, expr:Expr}>}> = [];
                
                for (task in tasks) switch task {
                    case Multiple(tasks):
                        Context.fatalError( 'Nested `Multiple(tasks)` is not allowed.', expr.pos );

                    case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg):
                        Resolver.findMethod(signature, module, statics, e.pos, fieldEReg, metaEReg).handle( function(o) switch o {
                            case Success(matches):
                                for (match in matches) {
                                    var idx = names.indexOf(match.name);

                                    if (idx == -1) {
                                        names.push( match.name );
                                        methods.push(
                                            { name:match.name, type:match.type, hits:[ {sig:signature, expr:e} ] }
                                        );

                                    } else {
                                        methods[idx].hits.push( {sig:signature, expr:e} );

                                    }

                                }
        
                            case Failure(error):
                                Context.fatalError( error.message, error.pos );
        
                        } );

                    case x:
                        Context.fatalError( 'Not implemented: $x', expr.pos );

                }

                var matches = [for (_ => obj in methods) obj];
                haxe.ds.ArraySort.sort(matches, (a, b) -> a.hits.length - b.hits.length );

                if (matches.length == 0) {
                    var field = matches[0];
                    result = field.hits[field.hits.length - 1].expr.field( field.name );

                } else if (matches.length > 0) {
                    while (matches.length > 0) {
                        var field = matches.pop();
                        var last = field.hits[field.hits.length - 1];

                        if (field.type.unify(last.sig)) {
                            result = last.expr.field( field.name );
                            break;

                        }

                    }

                } else {
                    Context.fatalError( NoMatches, expr.pos );

                }

            case ConvertValue(input, output, value): 
                Resolver.convertValue(input, output, value).handle( function(o) switch o {
                    case Success(expr): result = expr;
                    case Failure(error): Context.fatalError( error.message, error.pos );
                } );

            case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg): 
                Resolver.findMethod(signature, module, statics, e.pos, fieldEReg, metaEReg).handle( function(o) switch o {
                    case Success(matches):
                        if (matches.length == 0) {
                            result = e.field( matches[0].name );

                        } else if (matches.length > 0) {
                            while (matches.length > 0) {
                                var field = matches.pop();

                                if (field.type.unify(signature)) {
                                    result = e.field( field.name );
                                    break;

                                }

                            }

                        } else {
                            Context.fatalError( NoMatches, e.pos );

                        }

                    case Failure(error):
                        Context.fatalError( error.message, error.pos );

                } );

        }

        if (result == null) {
            Context.fatalError( TotalFailure, expr.pos );

        }

        // Not happy about `cast`ing this...
        result = macro cast $result;

        if (Debug && CoerceVerbose) {
            trace(result.toString());
        }

        return result;
    }

}