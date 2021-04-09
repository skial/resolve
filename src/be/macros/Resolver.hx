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
using haxe.macro.TypeTools;

@:forward
@:forwardStatics
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

@:forward
@:forwardStatics
enum abstract LocalMetas(Metas) to String {
    public var ResolverBind = ':resolver.self.bind';
}

class Resolver {

    private static final printer = new haxe.macro.Printer();

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

    public static function determineTask(expr:Expr, input:Type, output:Type, ?debug:Bool):ResolveTask {
        if (debug == null) debug = Debug && CoerceVerbose;
        var result:ResolveTask = null;

        // Yes this is a lazy hack but its for future me.
        if ('$output'.indexOf('TAbstract(be.types.Pick') > -1) {
            var c = output.toComplex();
            output = Context.typeof(macro (null:$c).asResolve());
        }

        //var rawInput = input.followWithAbstracts();
        //  Assume its in a raw form, i.e not an abstract or typedef redeclaration.
        var rawOutput = output;
        var isResolve = false;
        var fieldString = '';
        var metaString = '';
        var fieldEReg = ~//i;
        var metaEReg = ~//i;

        // Check if its a redefined type first.
        switch output {
            case TType(_.get() => def, _):
                output = def.type;

            case _:

        }

        switch output {
            case TAbstract(_.get() => {name:_.startsWith('Resolve') => true}, params): 
                isResolve = true;
                // Correct the `rawOutput` type.
                rawOutput = params[0];

                // Extract the EReg constants.
                for (i in 1...3) if (params[i] != null) switch params[i] {
                    case TInst(_.get() => {kind:KExpr(_.expr => EConst(CRegexp(r, o)))}, _):
                        if (debug) {
                            trace( i, r, o );
                        }
                        if (i == 1) fieldEReg = new EReg(fieldString = r, o);
                        if (i == 2) metaEReg = new EReg(metaString = r, o);

                    case x:
                        if (debug) trace( x );

                }
                
            case x: 
                if (debug) trace( x );

        }

        var isMethod = switch rawOutput {
            case TFun(_, _): true;
            case _: false;
        }
        
        if (debug) {
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
                    if (debug) trace( 'static abstract    :   ' + absr.toString() );
                    var ident = absr.toString().resolve();
                    var tasks = [
                        SearchMethod(rawOutput, TInst(clsr, []), true, ident, fieldEReg, metaEReg),
                        SearchMethod(rawOutput, TAbstract(absr, []), true, ident, fieldEReg, metaEReg),
                    ];
                    result = Multiple(tasks);
                
                // var _:Resolve<$rawOutput, EReg, EReg> = Class;
                case TAnonymous(_.get() => {status:AClassStatics(ref)}):
                    if (debug) trace( 'static class    :   ' + ref.toString() );
                    result = SearchMethod(rawOutput, TInst(ref, []), true, ref.toString().resolve(), fieldEReg, metaEReg);

                /*
                var instance:Class = new Class();
                var _:Resolve<$rawOutput, EReg, EReg> = instance;
                */
                case TInst(ref = _.get() => cls, params) if (cls.constructor != null && !cls.meta.has(Metas.CoreApi)):
                    if (debug) trace( 'instance class    :   ' + cls.name );
                    result = SearchMethod(rawOutput, TInst(ref, params), false, expr, fieldEReg, metaEReg);

                /*
                var instance:Abstract = new Abstract()/implicit or passive cast;
                var _:Resolve<$rawOutput, EReg, EReg> = instance;
                */
                case TAbstract(absr = _.get() => abs, params):
                    if (debug) trace( 'Instance Abstract   :   ' + absr.toString() );
                    var clsr = abs.impl;
                    var tasks = [];

                    if (clsr != null) {
                        if (debug) trace( 'Checking the abstract implemenation class for instance fields.' );
                        // Check the implementation class for instance fields first.
                        tasks.push( SearchMethod(rawOutput, TInst(clsr, []), false, expr, fieldEReg, metaEReg) );

                    }

                    if (metaString != '') {
                        if (debug) trace( 'Checking Abstract instance & static fields');
                        // It has a metadata ereg, so set the abstract to be checked.
                        tasks.push( SearchMethod(rawOutput, TAbstract(absr, params), true, absr.toString().resolve(), fieldEReg, metaEReg) );
                        tasks.push( SearchMethod(rawOutput, TAbstract(absr, params), false, expr, fieldEReg, metaEReg) );
                    }

                    result = (tasks.length == 1) ? tasks[0] : Multiple(tasks);

                case x:
                    throw x;

            }

        } else if (isResolve && !isMethod) {
            result = SearchProperty(rawOutput, input.reduce(), false, expr, fieldEReg, metaEReg);

        } else {
            // var _:$output = coerce($expr:$input);
            result = ConvertValue(input, output, expr);

        }

        if (debug) {
            switch result {
                case Multiple(tasks):
                    trace('<Multiple>');
                    for (task in tasks) trace( task );

                case _:
                    trace(result);

            }
        }

        return result;
    }

    public static function findMethod(signature:Type, module:Type, statics:Bool, pos:Position, ?fieldEReg:EReg, ?metaEReg:EReg, ?debug:Bool):Outcome<Array<{name:String, type:Type, meta:Metadata}>, Error> {
        if (debug == null) debug = Debug && CoerceVerbose;
        var results = [];
        var blankField = fieldEReg == null || '$fieldEReg'.startsWith('~//');
        var blankMeta = metaEReg == null || '$metaEReg'.startsWith('~//');
        
        if (debug) {
            trace( 'sig         :   ' + signature );
            trace( 'use statics :   ' + statics );
            trace( 'field ereg  :   ' + fieldEReg );
            trace( 'meta ereg   :   ' + metaEReg );
        }

        switch signature {
            case TFun(args, ret):
                var moduleID = module.getID();

                if (debug) {
                    trace( 'type        :   ' + moduleID );
                    trace( 'args        :   ' + args );
                    trace( 'return type :   ' + ret );
                }

                var fields:Array<{name:String, type:Type, meta:Metadata}> = switch module {
                    // The class which is auto generated for abstracts.
                    case TInst(clsr = _.get() => cls = {kind:KAbstractImpl(absr)}, params):
                        if (debug) {
                            trace( "Instance abstract `new T`" ); 
                        }
                        var fs = [];
                        // Afaik, all abstract methods get converted to statics?
                        var sfields = cls.statics.get();

                        if (!statics) {
                            var abs = absr.get();
                            // Get the underlying type of the Abstract
                            var raw = abs.type;
                            /**
                                The compiler used to mark all non static fields in an
                                Abstract which would be converted to statics with
                                `@:impl` metadata, which helped reduce fields to check
                                against.
                                ---
                                All the tests still pass, hopefully it was a pointless check
                                in this first place.
                            **/
                            var impls = sfields;//.filter( f -> f.meta.has(Metas.Impl) );
                            
                            for (field in impls) {
                                switch field.type.follow() {
                                    case x = TFun(args, ret):
                                        if (debug) {
                                            trace( args.length, args );
                                            trace( args[0].t, args[0].t.followWithAbstracts(), args[0].t.followWithAbstracts().unify(raw) );

                                        }
                                        /**
                                            Since we are searching an Abstract type as an instance/reference,
                                            e.g `_:Resolve<_, _, _> = ref;` the type signature needs patching.
                                            ---
                                            Abstract fields that are written as non static fields get
                                            converted to static fields, with the Abstract type as the first arg.
                                            `function foo(v:String):Bool` -> `static function foo(self:Abs, v:String):Bool`
                                            ---
                                            Pop the first arg off the type signature but mark the type with
                                            `@:resolver.self.bind`, this is needed when creating the call expression.
                                        **/
                                        if (args.length > 1 && args[0].t.followWithAbstracts().unify(raw)) {
                                            field.meta.add( ResolverBind, [macro $v{args.length-1}], field.pos );
                                            fs.push( {
                                                name: field.name,
                                                type: TFun(args.slice(1), ret),
                                                meta: field.meta.get(),
                                            } );

                                        } else {
                                            if (debug) trace( field.name, x );

                                        }

                                    case x:
                                        if (debug) trace( field.name, x );

                                }

                            }

                        } else {
                            // See `@:impl` commment above.
                            for (field in sfields) /*if (!field.meta.has(Metas.Impl))*/ {
                                fs.push( {name:field.name, type:field.type, meta:field.meta.get()} );
                            }

                        }

                        fs;

                    case TInst(_.get() => cls, params):
                        if (debug) trace( 'Class' );
                        var fs = statics ? cls.statics.get() : cls.fields.get();
                        fs
                            .filter( f -> f.kind.match( FMethod(_) ))
                            .map( f -> {name:f.name, type:f.type, meta:f.meta.get()} );

                    case TAbstract(_.get() => abs, params) if (metaEReg != null):
                        if (debug) {
                            trace( 'Abstract `:T`' );
                            trace( 'Check statics:  $statics' );
                        }

                        var fs = [];

                        if (statics) {
                            /**
                                Abstract features, dependent on metadata has already been parsed by the compiler,
                                but we still have to check the regular expression matches, manually.
                            **/
                            if (metaEReg.match('@' + Metas.From)) {
                                for (f in abs.from) if (f.field != null) {
                                    fs.push( {name:f.field.name, type:f.field.type, meta:f.field.meta.get()} );
    
                                }
    
                            }
                            
                            // Check all Binops
                            var op = '@' + Metas.Op;
                            var binop = ['+', '-', '/', '*', '<<', '>>', '>>>', '|', '&', '^', '%', '=', '!=', '>', '>=', '<', '<=', '&&', '||', '...', '=>', 'in'];
                            // Push binop assigns operators. Eg. `+=` or `*=`.
                            for (i in 0...12) binop.push( binop[i] + '=' );
                            
                            if (debug) trace( metaEReg );
                            for (b in binop) {
                                if (metaEReg.match(op + '(A $b B)')) {
                                    if (debug) {
                                        trace( metaEReg );
                                        trace( 'Matched binop:  $b' );
                                    }

                                    for (f in abs.binops) if (f.field != null) {
                                        if (debug) trace( 'Adding @:op overload `$b` method ${f.field.name}' );
                                        fs.push( {name:f.field.name, type:f.field.type, meta:f.field.meta.get()} );
                                    }

                                    // TODO Should we break on the first match...
                                    break;
                                }

                            }
    
                            var unop = ['++', '--', '!', '-', '~'];
                            for (u in unop) if (metaEReg.match(op + '(${u}A)')) {
                                for (f in abs.unops) if (f.field != null) {
                                    fs.push( {name:f.field.name, type:f.field.type, meta:f.field.meta.get()} );
                                }

                                // TODO Should we break on the first match...
                                break;
                            }

                            // Check postfix.
                            for (u in ['++', '--']) if (metaEReg.match(op + '(A$u)')) {
                                for (f in abs.unops) if (f.field != null) {
                                    fs.push( {name:f.field.name, type:f.field.type, meta:f.field.meta.get()} );
                                }
                                break;
                            }
    
                            // Check array access
                            if (metaEReg.match(op + '([])') || metaEReg.match('@' + Metas.ArrayAccess)) for (f in abs.array) {
                                fs.push( {name:f.name, type:f.type, meta:f.meta.get()} );
                            }

                            // Check resolve
                            if (metaEReg.match(op + '(a.b)') || metaEReg.match('@' + Metas.Resolve)){
                                if (abs.resolve != null) fs.push( {name:abs.resolve.name, type:abs.resolve.type, meta:abs.resolve.meta.get()} );
                                if (abs.resolveWrite != null) fs.push( {name:abs.resolveWrite.name, type:abs.resolveWrite.type, meta:abs.resolveWrite.meta.get()} );
                            }

                        } else {
                            // Check @:to implicit casts
                            if (metaEReg.match('@' + Metas.To)) for (f in abs.to) {
                                fs.push( {name:f.field.name, type:f.field.type, meta:f.field.meta.get()} );
                            }

                        }

                        fs;

                    case x:
                        if (debug) {
                            trace(x);
                        }

                        [];

                }

                fields = fields.filter( f -> f.name != '' );

                if (debug) {
                    trace( 'checking    :   ' + fields.map( f->f.name ) );
                }

                haxe.ds.ArraySort.sort( fields, (f1, f2) -> {
                    var fieldMatch = blankField;
                    var metaMatch = blankMeta;
                    
                    var f1total = 0;
                    var f2total = 0;

                    /**
                        Check the equality of types signatures, which is preferred over unifying types.
                        Type to String equality is gonna bite me in the ass.
                    **/
                    switch ([signature, f1.type, f2.type]) {
                        case [TFun(args, ret), TFun(args1, ret1), TFun(args2, ret2)]:
                            var idents = args.map( a -> a.t.toString() );
                            var retIdent = ret.toString();

                            if (args.length == args1.length && retIdent == ret1.toString()) {
                                for (i in 0...args1.length) if (idents[i] == args1[i].t.toString()) {
                                    f1total++;
                                }

                            }

                            if (args.length == args2.length && retIdent == ret2.toString()) {
                                for (i in 0...args2.length) if (idents[i] == args2[i].t.toString()) {
                                    f2total++;
                                }
                                
                            }

                            if (f1.type.unify(signature)) f1total++;
                            if (f2.type.unify(signature)) f2total++;

                        case _:

                    }

                    if (!fieldMatch) {
                        switch [fieldEReg.match(f1.name), fieldEReg.match(f2.name)] {
                            case [true, false]: f1total++;
                            case [false, true]: f2total++;
                            case _:
                        }

                    }

                    if (!metaMatch) {
                        for (meta in f1.meta) {
                            var str = printer.printMetadata(meta);
                            if (debug) trace(str);
                            if (metaEReg.match( str )) f1total++;
                        }

                        for (meta in f2.meta) {
                            var str = printer.printMetadata(meta);
                            if (debug) trace(str);
                            if (metaEReg.match( str )) f2total++;
                        }

                    }

                    if (debug) {
                        trace( f1.name, f2.name, f1total, f2total, f1total - f2total );
                    }

                    return f1total - f2total;
                } );

                if (debug) {
                    trace( 'sorted      :   ' + fields.map( f->f.name ) );
                }

                results = fields;

            case x:
                return Failure(new Error( NotFound, NotFunction + ' Not ${x.getID()}', pos ));

        }

        return Success(results);
    }

    public static function findProperty(signature:Type, module:Type, statics:Bool, pos:Position, ?fieldEReg:EReg, ?metaEReg:EReg, ?debug:Bool):Outcome<Array<{name:String, type:Type, meta:Metadata}>, Error> {
        if (debug == null) debug = Debug && CoerceVerbose;
        var results = [];
        var blankField = fieldEReg == null || '$fieldEReg'.startsWith('~//');
        var blankMeta = metaEReg == null || '$metaEReg'.startsWith('~//');
        
        if (debug) {
            trace( 'module  :   ' + module.getID() );
        }

        var fields = switch module {
            case TInst(_.get() => cls, params):
                if (statics) {
                    cls.statics.get();

                } else {
                    cls.fields.get();

                }

            case x:
                if (debug) trace( x );
                [];

        }

        fields = fields
        .filter( field -> {
            if (field.kind.match( FMethod(_) )) return false;

            if (debug) {
                trace( '<filtering properties>' );
                trace( 'field name  :   ' + field.name );
                trace( 'field type  :   ' + field.type.toString() );
            }

            var typeMatch = field.type.unify(signature);
            var nameMatch = !blankField ? fieldEReg.match( field.name ) : blankField;
            var metaMatch = !blankMeta ? field.meta.get().filter( m -> metaEReg.match( printer.printMetadata(m) )).length > 0 : blankMeta;
            return typeMatch && nameMatch && metaMatch;
        } );

        return Success(fields.map( f -> {name:f.name, meta:f.meta.get(), type:f.type }));
    }

    public static function convertValue(input:Type, output:Type, value:Expr, ?debug:Bool):Outcome<Expr, Error> {
        if (debug == null) debug = Debug && CoerceVerbose;
        var inputID = input.getID();
        var outputID = output.getID();
        var pos = value.pos;

        if (debug) {
            trace( 'input       :   ' + input );
            trace( 'output      :   ' + output );
            trace( 'value       :   ' + value.toString() );
            trace( 'input id    :   ' + inputID );
            trace( 'output id   :   ' + outputID );
        }
        
        if (typeMap.exists( inputID )) {
            var sub = typeMap.get( inputID );
            if (sub.exists( outputID )) {
                return Success( macro @:pos(pos) $e{sub.get( outputID )}($value) );

            }

        }

        var isAbstract = output.reduce().match(TAbstract(_, _));
        var outputComplex = output.toComplexType();
        var unified = ( isAbstract && (macro ($value:$outputComplex)).typeof().isSuccess() ) || 
        ( input.unify(output) || input.unify(output.follow()) || input.follow().unify(output) || input.follow().unify(output.follow()) );

        if (debug) {
            trace( 'unified         :   ' + unified );
            trace( 'is abstract     :   ' + isAbstract );
            trace( 'out ctype       :   ' + outputComplex.toString() );
        }

        if (unified) {
            return Success( macro @:pos(pos) ($value:$outputComplex) );

        }

        var error:Error = null;
        var outMatchesArray = (macro new Array()).typeof().sure().unify(output);
        var inMatchesArray = (macro new Array()).typeof().sure().unify(input);

        if (debug) {
            trace( 'IN unify []     :   ' + inMatchesArray );
            trace( 'OUT unify []    :   ' + outMatchesArray );
        }
        
        // Ouput expects an array, so just wrap the value. `[value]`.
        if (outMatchesArray && !inMatchesArray) {
            // Switch into the Array `<T>` type and fetch its type parameter.
            switch output {
                case TInst(_, [t1]):
                    if (debug) trace( '[] `<T>`    :   ' + t1 );

                    switch convertValue(input, t1.follow(), value) {
                        case Success(r): 
                            return Success( macro @:pos(pos) [$r] );

                        case Failure(e): 
                            error = e;

                    }

                case x:
                    if (debug) trace( x );

            }

        } 
        
        // Map an array. `array1.map( valueIn -> valueOut )`
        if (inMatchesArray && outMatchesArray) {
            if (debug) trace( '---map arrays---' );
            var t1 = input;
            var t2 = output;
            // Get each arrays `<T>` type.
            switch input {
                case TInst(_, [t]): t1 = t.follow();
                case x: if (debug) trace( x );
            }

            switch output {
                case TInst(_, [t]): t2 = t.follow();
                case x: if (debug) trace( x );
            }

            /**
                Get the expr needed to convert from one type to another.
                Use `macro v` as the expr, as the mapping happens after this, if successful.
            **/
            switch convertValue(t1, t2, macro v) {
                case Success(r): return Success( macro @:pos(pos) $value.map(v->$r) );
                case Failure(e): error = e;
            }

        }

        // Fallback to looking up a function.
        var inputComplex = input.toComplexType();
        var signature = (macro:$inputComplex->$outputComplex).toType().sure();

        if (debug) {
            trace( 'input ctype     :   ' + inputComplex.toString() );
            trace( 'output ctype    :   ' + outputComplex.toString() );
            trace( 'sig             :   ' + signature );
        }

        var tmp:Expr = null;

        switch findMethod(signature, output, true, pos) {
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
                    error = new Error( NotFound, NoMatches, pos );

                }

            case Failure(err):
                error = err;

        };

        if (error != null) return Failure(error);
        
        return Success( tmp == null ? value : macro @:pos(pos) $tmp($value) );
    }

    public static function handleTask(task:ResolveTask, ?debug:Bool):Expr {
        if (debug == null) debug = Debug && CoerceVerbose;
        var result:Expr = null;
        var pos = Context.currentPos();

        switch task {
            // Multiple is a mess still.
            case Multiple(tasks):
                var names:Array<String> = [];
                var methods:Array<{name:String, type:Type, meta:Metadata, hits:Array<{sig:Type, expr:Expr}>}> = [];
                
                for (task in tasks) switch task {
                    case Multiple(tasks):
                        Context.fatalError( NoNesting, pos );

                    case SearchProperty(signture, module, statics, expr, ereg, meta):
                        Context.fatalError( 'Searching multiple properties is not supported yet.', pos );

                    case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg):
                        if (debug) trace( 'multi task  :   search methods' );
                        switch Resolver.findMethod(signature, module, statics, e.pos, fieldEReg, metaEReg) {
                            case Success(matches):
                                if (matches.length == 0) continue;
                                if (debug) trace( 'matches     :   ' + matches.map( m -> m.name ) );

                                for (match in matches) {
                                    var idx = names.indexOf(match.name);

                                    if (idx == -1) {
                                        names.push( match.name );
                                        methods.push(
                                            { name:match.name, type:match.type, meta:match.meta, hits:[ {sig:signature, expr:e} ] }
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

                if (debug) trace( 'matches     :   ' + matches.map( m -> m.name + ':' + m.hits.length) );

                if (matches.length == 1) {
                    var field = matches[0];
                    result = field.hits[field.hits.length - 1].expr.field( field.name );

                } else if (matches.length > 1) {
                    while (matches.length > 0) {
                        var field = matches.pop();
                        var last = field.hits[field.hits.length - 1];

                        if (debug) {
                            trace( '--checking...--' );
                            trace( 'field name      :   ' + field.name );
                            trace( 'normal type     :   ' + field.type.toString() );
                            trace( 'reduced type    :   ' + field.type.follow().toString() );
                            trace( 'last hit sig    :   ' + last.sig.toString() );
                        }

                        if (field.type.follow().unify(last.sig)) {
                            if (debug) {
                                trace( '<--unified-->' );
                                trace( 'field name  :   ' + field.name );
                                trace( 'last expr   :   ' + last.expr.toString() );
                            }
                            result = last.expr.field( field.name );

                            /**
                                This means an instance/reference to an Abstract was passed in,
                                and a static field was matched, requiring the first arg to the ref.
                            **/
                            var binder = field.meta.filter( m -> m.name == ResolverBind );
                            if (binder.length != 0) {
                                var expr = switch tasks[0] {
                                    case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg): e;
                                    case _: null;
                                }

                                var args = [macro $e{expr}];
                                for (i in 0...(Std.parseInt( binder[0].params[0].toString() ))) {
                                    args.push( macro _ );
                                }

                                // I assume the compiler is smart enough to remove the `.bind`
                                result = macro $e{result}.bind($a{args});
                            }

                            break;

                        } else {
                            if (debug) {
                                trace('<--mismatch-->');
                                trace( 'field name  :   ' + field.name );
                            }

                        }

                    }

                } else {
                    Context.fatalError( NoMatches, pos );

                }

                if (debug) trace( 'multi result:   ' + result.toString() );

            case ConvertValue(input, output, value): 
                switch Resolver.convertValue(input, output, value) {
                    case Success(expr): 
                        result = expr;

                    case Failure(error): 
                        Context.fatalError( error.message, error.pos );
                        
                };

            case SearchProperty(signature, module, statics, e, fieldEReg, metaEReg):
                switch Resolver.findProperty(signature, module, statics, e.pos, fieldEReg, metaEReg) {
                    case Success(matches):
                        trace( matches );
                        if (matches.length == 1) {
                            result = e.field( matches[0].name );

                        } else if (matches.length > 1) {
                            while (matches.length > 0) {
                                var field = matches.pop();

                                if (debug) {
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
                                    if (debug) {
                                        trace( 'Field `' + field.name + '` type ' + field.type + ' failed to match against ' + signature );
                                    }

                                }

                            }

                        } else {
                            Context.fatalError( NoMatches, e.pos );

                        }

                    case Failure(error):
                        Context.fatalError( error.message, error.pos );

                }

            case SearchMethod(signature, module, statics, e, fieldEReg, metaEReg):
                switch Resolver.findMethod(signature, module, statics, e.pos, fieldEReg, metaEReg) {
                    case Success(matches):
                        if (matches.length == 1) {
                            result = e.field( matches[0].name );

                        } else if (matches.length > 1) {
                            while (matches.length > 0) {
                                var field = matches.pop();

                                if (debug) {
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
                                    if (debug) {
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