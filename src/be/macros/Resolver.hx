package be.macros;

import haxe.macro.*;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Metas;
import haxe.macro.Defines;
import be.coerce.Errors;
import be.coerce.ResolveTask;

using StringTools;
using haxe.macro.Context;
using tink.CoreApi;
using tink.MacroApi;

enum abstract LocalDefines(Defines) {
    public var CoerceVerbose = 'coerce_verbose';
    
    @:to public inline function asBool():Bool {
		return haxe.macro.Context.defined(this);
	}

    @:op(A == B) private static function equals(a:LocalDefines, b:Bool):Bool;
    @:op(A && B) private static function and(a:LocalDefines, b:Bool):Bool;
    @:op(A != B) private static function not(a:LocalDefines, b:Bool):Bool;
    @:op(!A) private static function negate(a:LocalDefines):Bool;
}

class Resolver {

    @:persistent public static var stringMap = [
        'Int' => macro Std.parseInt,
        'Float' => macro Std.parseFloat,
        'Date' => macro std.Date.fromString,
        'String' => macro (v -> v),
        'Bool' => macro (v -> v.toLowerCase() == 'true'),
    ];

    @:persistent public static var intMap = [
        'String' => macro Std.string,
    ];

    @:persistent public static var floatMap = [
        'String' => macro Std.string,
        'Date' => macro std.Date.fromTime,
    ];

    @:persistent public static var boolMap = [
        'String' => macro Std.string,
    ];
    
    @:persistent public static var typeMap = [
        'String' => stringMap,
        'Int' => intMap,
        'Float' => floatMap,
        'Bool' => boolMap,
        //'Array' => new Map()
    ];

    public static function determineTask(expr:Expr, input:Type, output:Type):ResolveTask {
        var result = null;

        // Yes this is a lazy hack but its for future me.
        if ('$output'.indexOf('TAbstract(be.types.Pick') > -1) {
            var c = output.toComplex();
            output = Context.typeof(macro (null:$c).asResolve());
        }

        var rawInput = input.followWithAbstracts();
        //  Assume its in a raw form, i.e not an abstract or typedef redeclaration.
        var rawOutput = output;
        var isResolve = false;
        var fieldEReg = ~//i;
        var metaEReg = ~//i;

        // Check if its a redefined type first.
        switch output {
            case TType(_.get() => def, _):
                output = def.type;

            case _:

        }

        switch output {
            case TAbstract(_.get() => {name:'Resolve'}, params): 
                isResolve = true;
                // Correct the `rawOutput` type.
                rawOutput = params[0];

                // Extract the EReg constants.
                for (i in 1...3) if (params[i] != null) switch params[i] {
                    case TInst(_.get() => {kind:KExpr(_.expr => EConst(CRegexp(r, o)))}, _):
                        if (i == 1) fieldEReg = new EReg(r, o);
                        if (i == 2) metaEReg = new EReg(r, o);

                    case x:
                        if (Debug && CoerceVerbose) trace( x );

                }
                
            case x: 
                if (Debug && CoerceVerbose) trace( x );

        }

        var isMethod = switch rawOutput {
            case TFun(_, _): true;
            case _: false;
        }
        
        if (Debug && CoerceVerbose) {
            trace( 'expression      :   ' + expr.toString() );
            trace( 'input type      :   ' + input );
            trace( 'input reduced   :   ' + input.reduce() );
            trace( 'output type     :   ' + output );
            trace( 'output reduced  :   ' + rawOutput );
            trace( 'function?       :   ' + isMethod );
            trace( 'resolve?        :   ' + isResolve );
            trace( 'field ereg      :   ' + fieldEReg );
            trace( 'meta ereg       :   ' + metaEReg );
        }

        if (isMethod) {
            switch input.reduce() {
                // var _:Resolve<$rawOutput, EReg, EReg> = Abstract;
                case TAnonymous(_.get() => {status:AClassStatics((clsr = _.get() =>  {kind:KAbstractImpl(absr)})) }):
                    result = SearchMethod(rawOutput, TAbstract(absr, []), true, absr.toString().resolve(), fieldEReg, metaEReg);

                // var _:Resolve<$rawOutput, EReg, EReg> = Class;
                case TAnonymous(_.get() => {status:AClassStatics(ref)}):
                    result = SearchMethod(rawOutput, TInst(ref, []), true, ref.toString().resolve(), fieldEReg, metaEReg);

                /*
                var instance:Class = new Class();
                var _:Resolve<$rawOutput, EReg, EReg> = instance;
                */
                case TInst(_.get() => t, params) if (t.constructor != null && !t.meta.has(Metas.CoreApi)):
                    result = SearchMethod(rawOutput, input.reduce(), false, expr, fieldEReg, metaEReg);

                /*
                var instance:Abstract = new Abstract()/implicit or passive cast;
                var _:Resolve<$rawOutput, EReg, EReg> = instance;
                */
                case TAbstract(ref = _.get() => abs, params):
                    result = Multiple([
                        /**
                            Assume its an Abstract instance, so search instance fields first.
                        **/
                        SearchMethod(rawOutput, input.reduce(), false, expr, fieldEReg, metaEReg),
                        SearchMethod(rawOutput, TAbstract(ref, params), true, ref.toString().resolve(), fieldEReg, metaEReg)
                    ]);

                case x:
                    throw x;

            }

        } else {
            // var _:$output = coerce($expr:$input);
            result = ConvertValue(input, output, expr);

        }

        if (Debug && CoerceVerbose) {
            trace( result );
        }

        return result;
    }

    public static function findMethod(signature:Type, module:Type, statics:Bool, pos:Position, ?fieldEReg:EReg, ?metaEReg:EReg):Outcome<Array<{name:String, type:Type}>, Error> {
        var results = [];
        var blankField = fieldEReg == null || '$fieldEReg'.startsWith('~//');
        var blankMeta = metaEReg == null || '$metaEReg'.startsWith('~//');
        
        if (Debug && CoerceVerbose) {
            trace( 'sig         :   ' + signature );
            trace( 'use statics :   ' + statics );
            trace( 'field ereg  :   ' + fieldEReg );
            trace( 'meta ereg   :   ' + metaEReg );
        }

        switch signature {
            case TFun(args, ret):
                var moduleID = module.getID();

                if (Debug && CoerceVerbose) {
                    trace( moduleID );
                    trace( 'args: ' + args );
                    trace( 'return type: ' + ret );
                }

                var fields:Array<{name:String, type:Type, meta:Metadata}> = switch module {
                    case TInst(_.get() => t, params):
                        var fs = statics ? t.statics.get() : t.fields.get();
                        fs.map( f -> {name:f.name, type:f.type, meta:f.meta.get()} );

                    case TAbstract(_.get() => t, params):
                        [for (f in t.from) 
                            (f.field == null) 
                                ? {name:'', type:f.t, meta:[]} 
                                : {name:f.field.name, type:f.field.type, meta:f.field.meta.get()}
                        ]
                        .concat([
                        for(f in t.binops)
                            {name:f.field.name, type:f.field.type, meta:f.field.meta.get()}
                        ]);

                    case x:
                        if (Debug && CoerceVerbose) {
                            trace(x);
                        }

                        [];

                }

                fields = fields.filter( f -> f.name != '' );

                if (Debug && CoerceVerbose) {
                    trace( 'checking    :   ' + fields.map( f->f.name ) );
                }

                haxe.ds.ArraySort.sort( fields, (f1, f2) -> {
                    var fieldMatch = blankField;
                    var metaMatch = blankMeta;
                    
                    var f1total = 0;
                    var f2total = 0;

                    if (!fieldMatch) {
                        switch [fieldEReg.match(f1.name), fieldEReg.match(f2.name)] {
                            case [true, false]: f1total++;
                            case [false, true]: f2total++;
                            case _:
                        }

                    }

                    if (!metaMatch) {
                        var printer = new haxe.macro.Printer();
                        for (meta in f1.meta) {
                            var str = printer.printMetadata(meta);
                            if (Debug && CoerceVerbose) trace(str);
                            if (metaEReg.match( str )) f1total++;
                        }

                        for (meta in f2.meta) {
                            var str = printer.printMetadata(meta);
                            if (Debug && CoerceVerbose) trace(str);
                            if (metaEReg.match( str )) f2total++;
                        }

                    }

                    if (Debug && CoerceVerbose) {
                        trace( f1.name, f2.name, f1total, f2total, f1total - f2total );
                    }

                    return f1total - f2total;
                } );

                if (Debug && CoerceVerbose) {
                    trace( 'sorted      :   ' + fields.map( f->f.name ) );
                }

                results = fields;

            case x:
                return Failure(new Error( NotFound, NotFunction + ' Not ${x.getID()}', pos ));

        }

        return Success(results);
    }

    public static function convertValue(input:Type, output:Type, value:Expr):Outcome<Expr, Error> {
        var result = null;
        var inputID = input.getID();
        var outputID = output.getID();
        var position = value.pos;

        if (Debug && CoerceVerbose) {
            trace( 'input       :   ' + input );
            trace( 'output      :   ' + output );
            trace( 'value       :   ' + value.toString() );
            trace( 'input id    :   ' + inputID );
            trace( 'output id   :   ' + outputID );
        }
        
        if (typeMap.exists( inputID )) {
            var sub = typeMap.get( inputID );
            if (sub.exists( outputID )) {
                result = macro @:pos(value.pos) $e{sub.get( outputID )}($value);

            }

        }

        if (result == null) {
            var outputComplex = output.toComplexType();
            var emptyArray = (macro new Array()).typeof().sure();
            var matchesArray = emptyArray.unify(output);
            var unified = input.unify(output);

            if (Debug && CoerceVerbose) {
                trace( matchesArray, unified, matchesArray && unified );
            }

            if (unified) {
                result = macro @:pos(value.pos) ($value:$outputComplex);

            } else if (matchesArray) {
                trace( matchesArray, outputComplex.toString() );

            }
        }
        
        if (result == null) {
            var inputComplex = input.toComplexType();
            var outputComplex = output.toComplexType();
            var signature = (macro:$inputComplex->$outputComplex).toType().sure();

            if (Debug && CoerceVerbose) {
                trace( inputComplex.toString() );
                trace( outputComplex.toString() );
                trace( signature );
            }

            var tmp:Expr = null;
            var error:Error = null;

            switch findMethod(signature, output, true, position) {
                case Success(matches):
                    if (matches.length == 1) {
                        tmp = outputID.resolve().field( matches[0].name );

                    } else if (matches.length > 1) {
                        while (matches.length > 1) {
                            var field = matches.pop();

                            if (field.type.unify(signature)) {
                                tmp = outputID.resolve().field( field.name );
                                break;

                            }

                        }

                    } else {
                        error = new Error( NotFound, NoMatches, value.pos );

                    }

                case Failure(err):
                    error = err;

            };

            if (error != null) return Failure(new Error( error.code, error.message, error.pos ));
            
            result = tmp == null ? value : macro @:pos(value.pos) $tmp($value);
        }

        if (result == null) return Failure(new Error( NotFound, TotalFailure, value.pos ));
        
        return Success(result);
    }

    public static function handleTask(task:ResolveTask):Expr {
        var result:Expr = null;
        var pos = Context.currentPos();

        switch task {
            case Multiple(tasks):
                var names:Array<String> = [];
                var methods:Array<{name:String, type:Type, hits:Array<{sig:Type, expr:Expr}>}> = [];
                
                for (task in tasks) switch task {
                    case Multiple(tasks):
                        Context.fatalError( NoNesting, pos );

                    case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg):
                        switch Resolver.findMethod(signature, module, statics, e.pos, fieldEReg, metaEReg) {
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
        
                        };

                    case x:
                        Context.fatalError( 'Not implemented: $x', pos );

                }

                var matches = [for (_ => obj in methods) obj];
                haxe.ds.ArraySort.sort(matches, (a, b) -> a.hits.length - b.hits.length );

                if (matches.length == 1) {
                    var field = matches[0];
                    result = field.hits[field.hits.length - 1].expr.field( field.name );

                } else if (matches.length > 1) {
                    while (matches.length > 0) {
                        var field = matches.pop();
                        var last = field.hits[field.hits.length - 1];

                        if (field.type.unify(last.sig)) {
                            result = last.expr.field( field.name );
                            break;

                        }

                    }

                } else {
                    Context.fatalError( NoMatches, pos );

                }

            case ConvertValue(input, output, value): 
                switch Resolver.convertValue(input, output, value) {
                    case Success(expr): 
                        result = expr;

                    case Failure(error): 
                        Context.fatalError( error.message, error.pos );
                        
                };

            case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg): 
                switch Resolver.findMethod(signature, module, statics, e.pos, fieldEReg, metaEReg) {
                    case Success(matches):
                        if (matches.length == 1) {
                            result = e.field( matches[0].name );

                        } else if (matches.length > 1) {
                            while (matches.length > 0) {
                                var field = matches.pop();

                                if (Debug && CoerceVerbose) {
                                    trace( '--checking...--' );
                                    trace( 'field name      :   ' + field.name );
                                    trace( 'normal type     :   ' + field.type );
                                    trace( 'reduced type    :   ' + field.type.follow() );
                                    trace( 'signature       :   ' + signature );
                                }

                                if (field.type.follow().unify(signature)) {
                                    result = e.field( field.name );
                                    break;

                                } else {
                                    if (Debug && CoerceVerbose) {
                                        trace( 'Field `' + field.name + '` type ' + field.type + ' failed to match against ' + signature );
                                    }

                                }

                            }

                        } else {
                            Context.fatalError( NoMatches, e.pos );

                        }

                    case Failure(error):
                        Context.fatalError( error.message, error.pos );

                };

        }

        if (result == null) {
            Context.fatalError( TotalFailure, pos );

        }

        return result;
    }

}