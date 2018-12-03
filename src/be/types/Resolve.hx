package be.types;

import haxe.Constraints.Function;

#if (eval || macro)
import haxe.macro.*;

using haxe.macro.Context;
using tink.CoreApi;
using tink.MacroApi;
#end
using StringTools;

abstract Method<T:Function>(T) from Function to Function {
    public inline function new(v) this = v;
    @:noCompletion public inline function get():T return this;

    @:from public static function of<T:Function>(v:T):Method<T> return new Method(v);
    @:from public static function fromResolve<T:Function>(v:Resolve<T, ~//>):Method<T> {
        return new Method(v.get());
    }
    @:to public function toResolve():Resolve<T, ~//i> return this;
}

#if (eval || macro)
enum ResolveTask {
    /**
        var m:String->Float = coerce(Type);
        var m:`signature` = coerce(`module`);
        var m:Resolve<String->Float, ~/int/i> = coerce(Type);
        var m:Resolve<`signature`, `ereg`> = coerce(`module`);
        ---
        If it can resolve to a function, it will look for a matching type `signature`
        on `module`
    **/
    SearchMethod(signature:Type, module:Type, statics:Bool, expr:Expr, ?ereg:EReg);

    /**
        var m:Date = coerce('2018-11-15');
        var m:`output` = coerce((`value`:`input`));
        ---
        Look through a known list of types for matching `input`=>`output`.
        If a type doesnt exist, search `output` for a `input->output` method.
    **/
    ConvertValue(input:Type, output:Type, value:Expr);
}
#end

@:callable @:notNull abstract Resolve<T:Function, @:const R:EReg>(T) to T {

    @:noCompletion public inline function get():T return this;
    @:from private static inline function fromFunction<T:Function>(v:T):Resolve<T, ~//i> return (cast v:Resolve<T, ~//i>);

    @:from public static macro function resolve<In, Out:Function>(expr:ExprOf<Class<In>>):ExprOf<Out> {
        var result = switch determineTask( expr, expr.typeof().sure(), Context.getExpectedType() ) {
            case SearchMethod(signature, module, statics, e, ereg): findMethod(signature, module, statics, e, ereg);
            case _: Context.fatalError( 'Use `Resolve.coerce` instead.', expr.pos );
        }
        #if (debug && coerce_verbose)
            trace(result.toString());
        #end
        return result;
    }

    @:from public static macro function coerce<In, Out>(expr:ExprOf<In>):ExprOf<Out> {
        var result = switch determineTask( expr, expr.typeof().sure(), Context.getExpectedType() ) {
            case ConvertValue(input, output, value): convertValue(input, output, value);
            case _: Context.fatalError( 'Use `Resolve.resolve` instead.', expr.pos );
        }
        #if (debug && coerce_verbose)
            trace(result.toString());
        #end
        return result;
    }

    #if (eval || macro)
    public static var stringMap = [
        'Int' => macro Std.parseInt,
        'Float' => macro Std.parseFloat,
        'Date' => macro std.Date.fromString,
        'String' => macro (v -> v),
    ];
    public static var intMap = [
        'String' => macro Std.string,
    ];
    public static var floatMap = [
        'String' => macro Std.string,
    ];
    public static var boolMap = [
        'String' => macro Std.string,
    ];
    public static var typeMap = [
        'String' => stringMap,
        'Int' => intMap,
        'Float' => floatMap,
        'Bool' => boolMap,
        //'Array' => new Map()
    ];

    public static function determineTask(expr:Expr, input:Type, output:Type):ResolveTask {
        var result = null;
        
        switch input.reduce() {
            case TAnonymous(_.get() => {status:AClassStatics(ref)}):
                var outputComplex = output.toComplex();
                var method = (macro be.types.Resolve.Method.fromResolve((null:$outputComplex))).typeof().sure();

                if (output.unify(method)) {
                    var methodComplex = method.toComplex();
                    var signature = (macro ((null:$outputComplex):$methodComplex).toResolve().get()).typeof().sure();
                    
                    result = SearchMethod(signature, TInst(ref, []), true, ref.toString().resolve());
                }
                
            case TInst(_.get() => t, params) if (t.constructor != null && !t.meta.has(':coreApi')):
                var outputComplex = output.toComplex();
                var method = (macro be.types.Resolve.Method.fromResolve((null:$outputComplex))).typeof().sure();

                if (output.unify(method)) {
                    var methodComplex = method.toComplex();
                    var signature = (macro ((null:$outputComplex):$methodComplex).toResolve().get()).typeof().sure();

                    result = SearchMethod(signature, input.reduce(), false, expr);
                }

            case x:
                result = ConvertValue(input, output, expr);

        }

        return result;
    }

    public static function findMethod(signature:Type, module:Type, statics:Bool, expr:Expr, ?ereg:EReg):Null<Expr> {
        var result = null;
        
        switch signature {
            case TFun(args, ret):
                var moduleID = module.getID();
                var fields = switch module {
                    case TInst(_.get() => t, params):
                        statics ? t.statics.get() : t.fields.get();

                    case x:
                        #if (debug && coerce_verbose)
                            trace(x);
                        #end
                        [];

                }

                var matches = [];

                if (fields.length > 0) for (field in fields) {
                    var eregMatch = true;
                    if (ereg != null) eregMatch = ereg.match(field.name);
                    if (eregMatch && field.type.unify(signature)) matches.push( field );

                }

                if (matches.length > 0) result = expr.field( matches[matches.length - 1].name );

            case x:
                Context.fatalError( 'Signature should be a function. Not ${x.getID()}', expr.pos );

        }

        if (result == null) {
            Context.fatalError( 'Unable to find a matching signature of ${signature.toComplex().toString()} on ${module.getID()}.', expr.pos );
        }

        return result;
    }

    public static function convertValue(input:Type, output:Type, value:Expr):Expr {
        var result = null;
        var inputID = input.getID();
        var outputID = output.getID();
        
        if (typeMap.exists( inputID )) {
            var sub = typeMap.get( inputID );
            if (sub.exists( outputID )) {
                result = macro @:pos(value.pos) $e{sub.get( outputID )}($value);

            }

        }
        
        if (result == null) {
            var inputComplex = input.toComplex();
            var outputComplex = output.toComplex();
            var signature = (macro:$inputComplex->$outputComplex).toType().sure();
            var tmp = findMethod(signature, output, true, outputID.resolve());
            
            result = tmp == null ? value : macro @:pos(value.pos) $tmp($value);
        }

        if (result == null) Context.fatalError( 'No expression can be found or constructed.', value.pos );

        return result;
    }
    #end

}